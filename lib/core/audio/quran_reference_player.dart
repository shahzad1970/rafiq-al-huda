import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../quran/quran_repository.dart';

class QuranReferencePlayer extends ChangeNotifier {
  static const _methods = MethodChannel('org.quranteacher/playback');
  static const _events = EventChannel('org.quranteacher/playback/events');

  StreamSubscription<dynamic>? _subscription;
  QuranReferenceAudio? _activeAudio;
  bool _playingWholeVerse = false;
  bool _disposed = false;
  QuranReferenceAudio? Function()? _nextVerse;
  bool playing = false;
  bool loading = false;
  bool downloading = false;
  int downloadCompleted = 0;
  int downloadTotal = 0;
  int? playingWordIndex;
  String? error;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> playVerse(
    QuranReferenceAudio audio, {
    QuranReferenceAudio? Function()? nextVerse,
  }) {
    _nextVerse = nextVerse;
    return _play(audio);
  }

  /// Teaching speech only. Never used as Qur'an recitation or recognition.
  Future<void> speakArabic(String text) {
    _nextVerse = null;
    return _play(
      const QuranReferenceAudio(
        remoteUrl: '',
        cacheKey: '',
        durationMilliseconds: 0,
        wordSegments: [],
      ),
      speechText: text,
    );
  }

  Future<void> playWord(
    QuranReferenceAudio audio,
    int wordIndex, {
    double rate = 1,
  }) async {
    if (wordIndex < 0 || wordIndex >= audio.wordSegments.length) {
      throw RangeError.index(wordIndex, audio.wordSegments);
    }
    final segment = audio.wordSegments[wordIndex];
    await _play(
      audio,
      wordIndex: wordIndex,
      startMilliseconds: segment.startMilliseconds,
      endMilliseconds: segment.endMilliseconds,
      rate: rate,
    );
  }

  Future<void> playWords(
    QuranReferenceAudio audio,
    int start,
    int end, {
    double rate = 1,
  }) async {
    if (start < 0 || end <= start || end > audio.wordSegments.length) {
      throw RangeError('Invalid reference phrase range');
    }
    await _play(
      audio,
      wordIndex: start,
      startMilliseconds: audio.wordSegments[start].startMilliseconds,
      endMilliseconds: audio.wordSegments[end - 1].endMilliseconds,
      rate: rate,
    );
  }

  Future<void> _play(
    QuranReferenceAudio audio, {
    int? wordIndex,
    int startMilliseconds = 0,
    int? endMilliseconds,
    double rate = 1,
    String? speechText,
  }) async {
    if (wordIndex != null) _nextVerse = null;
    error = null;
    _subscription ??= _events.receiveBroadcastStream().listen(
      (dynamic value) {
        if (_disposed) return;
        final event = Map<Object?, Object?>.from(value as Map);
        final state = event['state'];
        if (state == 'playing') {
          playing = true;
          loading = false;
        } else if (state == 'downloadProgress') {
          downloading = true;
          downloadCompleted = (event['completed'] as num?)?.toInt() ?? 0;
          downloadTotal = (event['total'] as num?)?.toInt() ?? 0;
        } else if (state == 'downloadCompleted') {
          downloading = false;
          downloadCompleted = downloadTotal;
        } else if (state == 'progress' && _playingWholeVerse) {
          final milliseconds = (event['positionMilliseconds'] as num?)?.toInt();
          if (milliseconds != null && _activeAudio != null) {
            playingWordIndex = wordIndexAt(_activeAudio!, milliseconds);
          }
        } else if (state == 'completed' || state == 'stopped') {
          final advance = state == 'completed' && _playingWholeVerse
              ? _nextVerse
              : null;
          _nextVerse = null;
          playing = false;
          loading = false;
          playingWordIndex = null;
          _activeAudio = null;
          _playingWholeVerse = false;
          final next = advance?.call();
          if (next != null) {
            unawaited(playVerse(next, nextVerse: advance));
            return;
          }
        } else if (state == 'error') {
          _nextVerse = null;
          playing = false;
          loading = false;
          playingWordIndex = null;
          _activeAudio = null;
          _playingWholeVerse = false;
          error = event['message'] as String? ?? 'Playback failed.';
        }
        notifyListeners();
      },
      onError: (Object value) {
        if (_disposed) return;
        playing = false;
        loading = false;
        downloading = false;
        playingWordIndex = null;
        _activeAudio = null;
        _playingWholeVerse = false;
        error = value.toString();
        notifyListeners();
      },
    );
    _activeAudio = audio;
    _playingWholeVerse = wordIndex == null;
    playingWordIndex = wordIndex;
    loading = true;
    notifyListeners();
    try {
      await _methods.invokeMethod<void>(
        speechText == null ? 'play' : 'speakArabic',
        {
          'text': ?speechText,
          if (audio.asset != null) 'asset': audio.asset,
          'remoteUrl': audio.remoteUrl,
          'cacheKey': audio.cacheKey,
          'startMilliseconds': startMilliseconds,
          'endMilliseconds': endMilliseconds,
          'rate': rate,
        },
      );
    } on PlatformException catch (exception) {
      playing = false;
      loading = false;
      playingWordIndex = null;
      _activeAudio = null;
      _playingWholeVerse = false;
      error = exception.message ?? exception.code;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    // Cancel before waiting for the native stop acknowledgement.
    _nextVerse = null;
    _playingWholeVerse = false;
    await _methods.invokeMethod<void>('stop');
    if (_disposed) return;
    playing = false;
    loading = false;
    playingWordIndex = null;
    _activeAudio = null;
    _playingWholeVerse = false;
    notifyListeners();
  }

  Future<void> downloadSurah(List<QuranAyah> ayahs) async {
    if (downloading) return;
    final audio = ayahs.map((ayah) => ayah.referenceAudio).nonNulls.toList();
    downloading = true;
    downloadCompleted = 0;
    downloadTotal = audio.length;
    error = null;
    notifyListeners();
    try {
      await _methods.invokeMethod<void>('cache', {
        'items': [
          for (final item in audio)
            {'remoteUrl': item.remoteUrl, 'cacheKey': item.cacheKey},
        ],
      });
      downloading = false;
      downloadCompleted = downloadTotal;
    } on PlatformException catch (exception) {
      downloading = false;
      error = exception.message ?? exception.code;
    }
    notifyListeners();
  }

  Future<void> deleteDownloads() async {
    await stop();
    await _methods.invokeMethod<void>('clearCache');
    downloadCompleted = 0;
    downloadTotal = 0;
    notifyListeners();
  }

  /// Maps the native player's exact position to the word being recited.
  /// Deliberate gaps before/between words remain unhighlighted.
  static int? wordIndexAt(QuranReferenceAudio audio, int milliseconds) {
    for (var index = 0; index < audio.wordSegments.length; index++) {
      final segment = audio.wordSegments[index];
      if (milliseconds >= segment.startMilliseconds &&
          milliseconds < segment.endMilliseconds) {
        return index;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _nextVerse = null;
    _playingWholeVerse = false;
    unawaited(_methods.invokeMethod<void>('stop'));
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
