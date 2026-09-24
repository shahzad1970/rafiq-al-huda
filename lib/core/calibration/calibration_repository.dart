import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum CalibrationLabel {
  carefulRecitation,
  deliberatePronunciationChange,
  skippedWord,
  repeatedWord,
  shortMadd,
  backgroundNoise,
  quietMicrophone,
}

extension CalibrationLabelText on CalibrationLabel {
  String get title => switch (this) {
    CalibrationLabel.carefulRecitation => 'Careful recitation',
    CalibrationLabel.deliberatePronunciationChange =>
      'Deliberate pronunciation change',
    CalibrationLabel.skippedWord => 'Word skipped',
    CalibrationLabel.repeatedWord => 'Word repeated',
    CalibrationLabel.shortMadd => 'Madd deliberately short',
    CalibrationLabel.backgroundNoise => 'Background noise',
    CalibrationLabel.quietMicrophone => 'Very quiet recitation',
  };
}

class CalibrationRecord {
  const CalibrationRecord({
    required this.id,
    required this.surah,
    required this.ayah,
    required this.label,
    required this.createdAt,
    required this.durationMilliseconds,
    required this.wavFileName,
    required this.metadataFileName,
    this.note,
  });

  final String id;
  final int surah;
  final int ayah;
  final CalibrationLabel label;
  final DateTime createdAt;
  final int durationMilliseconds;
  final String wavFileName;
  final String metadataFileName;
  final String? note;

  Map<String, Object?> toJson() => {
    'id': id,
    'surah': surah,
    'ayah': ayah,
    'label': label.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'durationMilliseconds': durationMilliseconds,
    'wavFileName': wavFileName,
    'metadataFileName': metadataFileName,
    'note': note,
  };

  factory CalibrationRecord.fromJson(Map<String, Object?> json) =>
      CalibrationRecord(
        id: json['id']! as String,
        surah: json['surah']! as int,
        ayah: json['ayah']! as int,
        label: CalibrationLabel.values.byName(json['label']! as String),
        createdAt: DateTime.parse(json['createdAt']! as String),
        durationMilliseconds: json['durationMilliseconds']! as int,
        wavFileName: json['wavFileName']! as String,
        metadataFileName: json['metadataFileName']! as String,
        note: json['note'] as String?,
      );
}

typedef CalibrationDirectoryProvider = Future<Directory> Function();

class LocalCalibrationRepository extends ChangeNotifier {
  LocalCalibrationRepository({CalibrationDirectoryProvider? directoryProvider})
    : _directoryProvider = directoryProvider ?? _defaultDirectory;

  static const sampleRate = 16000;
  static const maximumSeconds = 120;
  static const _indexFileName = 'index.json';
  static const _localDataChannel = MethodChannel('org.quranteacher/audio');

  final CalibrationDirectoryProvider _directoryProvider;
  final List<CalibrationRecord> _records = [];

  List<CalibrationRecord> get records => List.unmodifiable(_records);

  static Future<Directory> _defaultDirectory() async {
    if (!Platform.isIOS) {
      throw UnsupportedError('Calibration recordings are iPhone-only.');
    }
    final path = await _localDataChannel.invokeMethod<String>(
      'calibrationDirectory',
    );
    if (path == null || path.isEmpty) {
      throw StateError('The local calibration directory is unavailable.');
    }
    return Directory(path);
  }

  Future<void> load() async {
    final directory = await _directoryProvider();
    final index = File('${directory.path}/$_indexFileName');
    if (!await index.exists()) return;
    try {
      final values = jsonDecode(await index.readAsString()) as List;
      _records
        ..clear()
        ..addAll(
          values.map(
            (item) => CalibrationRecord.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          ),
        );
    } on Object {
      _records.clear();
    }
    notifyListeners();
  }

  Future<CalibrationRecord> save({
    required int surah,
    required int ayah,
    required CalibrationLabel label,
    required Uint8List pcm16le,
    required Map<String, Object?> recognitionMetadata,
    String? note,
  }) async {
    if (pcm16le.isEmpty || pcm16le.length.isOdd) {
      throw const FormatException('Calibration audio must be PCM16LE.');
    }
    if (pcm16le.length > sampleRate * 2 * maximumSeconds) {
      throw const FormatException('Calibration recording exceeds two minutes.');
    }

    final directory = await _directoryProvider();
    await _prepareDirectory(directory);
    final createdAt = DateTime.now().toUtc();
    final id = createdAt.microsecondsSinceEpoch.toString();
    final wavFileName = '${id}_s${surah}_a$ayah.wav';
    final metadataFileName = '${id}_s${surah}_a$ayah.json';
    final durationMilliseconds = pcm16le.length * 1000 ~/ (sampleRate * 2);
    final record = CalibrationRecord(
      id: id,
      surah: surah,
      ayah: ayah,
      label: label,
      createdAt: createdAt,
      durationMilliseconds: durationMilliseconds,
      wavFileName: wavFileName,
      metadataFileName: metadataFileName,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
    );

    await File('${directory.path}/$wavFileName')
        .writeAsBytes(_wav(pcm16le), flush: true);
    await File('${directory.path}/$metadataFileName').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        ...record.toJson(),
        'audio': {
          'sampleRate': sampleRate,
          'channels': 1,
          'encoding': 'pcm16le',
          'wavFile': wavFileName,
        },
        'recognition': recognitionMetadata,
      }),
      flush: true,
    );
    _records.insert(0, record);
    await _persistIndex(directory);
    notifyListeners();
    return record;
  }

  Future<void> delete(CalibrationRecord record) async {
    final directory = await _directoryProvider();
    await _deleteIfPresent(File('${directory.path}/${record.wavFileName}'));
    await _deleteIfPresent(
      File('${directory.path}/${record.metadataFileName}'),
    );
    _records.removeWhere((item) => item.id == record.id);
    await _persistIndex(directory);
    notifyListeners();
  }

  Future<void> deleteAll() async {
    final directory = await _directoryProvider();
    if (await directory.exists()) await directory.delete(recursive: true);
    _records.clear();
    notifyListeners();
  }

  Future<void> _persistIndex(Directory directory) async {
    await _prepareDirectory(directory);
    await File('${directory.path}/$_indexFileName').writeAsString(
      jsonEncode(_records.map((record) => record.toJson()).toList()),
      flush: true,
    );
  }

  static Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }

  static Future<void> _prepareDirectory(Directory directory) async {
    await directory.create(recursive: true);
    if (Platform.isIOS) {
      await _localDataChannel.invokeMethod<void>('excludeFromBackup', {
        'path': directory.path,
      });
    }
  }

  @visibleForTesting
  static Uint8List wavBytes(Uint8List pcm16le) => _wav(pcm16le);

  static Uint8List _wav(Uint8List pcm16le) {
    final output = Uint8List(44 + pcm16le.length);
    final header = ByteData.sublistView(output);
    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        output[offset + i] = value.codeUnitAt(i);
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + pcm16le.length, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, pcm16le.length, Endian.little);
    output.setRange(44, output.length, pcm16le);
    return output;
  }
}
