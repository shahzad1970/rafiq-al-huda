import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/calibration/calibration_repository.dart';
import '../../core/quran/quran_repository.dart';
import '../recitation/recitation_controller.dart';
import 'debug_screen.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({
    super.key,
    required this.controller,
    required this.repository,
  });

  final RecitationController controller;
  final QuranRepository repository;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  late final QuranAyah? _originalAyah = widget.controller.expectedAyah;
  final _noteController = TextEditingController();
  CalibrationLabel _label = CalibrationLabel.carefulRecitation;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.discardPendingCalibration();
      if (widget.controller.expectedAyah == null) {
        widget.controller.selectAyah(widget.repository.getAyah(1, 1));
      }
    });
  }

  @override
  void dispose() {
    widget.controller.discardPendingCalibration();
    final original = _originalAyah;
    if (original != null) widget.controller.selectAyah(original);
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.controller.savePendingCalibration(
        label: _label,
        note: _noteController.text,
      );
      _noteController.clear();
      widget.controller.clearSession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test sample saved locally.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRecording(CalibrationRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this recording?'),
        content: Text(
          'Al-Fātiḥah ${record.ayah} · ${record.label.title}\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.calibration?.delete(record);
  }

  Future<void> _deleteAll() async {
    final count = widget.controller.calibration?.records.length ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all accuracy samples?'),
        content: Text(
          'This permanently removes $count labeled ${count == 1 ? "recording" : "recordings"} and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.calibration?.deleteAll();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final calibration = controller.calibration;
      final ayah = controller.expectedAyah!;
      final disabled = controller.listening || controller.busy || _saving;
      return PopScope(
        canPop: !controller.listening && !controller.busy,
        child: Scaffold(
          appBar: AppBar(title: const Text('Accuracy check')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Help improve the feedback',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Record known examples so the app can be tested without guessing. Choose what you intend to recite, then save only the attempts you want to keep. Nothing is uploaded.',
                ),
                if (calibration != null) ...[
                  const SizedBox(height: 16),
                  _AccuracyProgress(records: calibration.records),
                ],
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  children: List.generate(
                    7,
                    (index) => ChoiceChip(
                      label: Text('${index + 1}'),
                      selected: ayah.ayah == index + 1,
                      onSelected: disabled
                          ? null
                          : (_) {
                              controller.discardPendingCalibration();
                              controller.selectAyah(
                                widget.repository.getAyah(1, index + 1),
                              );
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    ayah.words.map((word) => word.displayText).join(' '),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'QuranIndoPak',
                      fontSize: 38,
                      height: 2.25,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CalibrationLabel>(
                  initialValue: _label,
                  decoration: const InputDecoration(
                    labelText: 'What will you recite?',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final label in CalibrationLabel.values)
                      DropdownMenuItem(value: label, child: Text(label.title)),
                  ],
                  onChanged: disabled
                      ? null
                      : (value) {
                          if (value != null) setState(() => _label = value);
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  enabled: !disabled,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'What did you change? (optional)',
                    hintText: 'Example: changed ح toward ه in الرحمٰن',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: controller.busy || _saving
                      ? null
                      : controller.listening
                      ? controller.stopMicrophone
                      : controller.startCalibrationMicrophone,
                  icon: Icon(controller.listening ? Icons.stop : Icons.mic),
                  label: Text(
                    controller.listening
                        ? 'Stop accuracy recording'
                        : 'Record test attempt',
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: CustomPaint(
                    painter: WaveformPainter(controller.waveform),
                  ),
                ),
                Text(
                  controller.listening
                      ? 'Recording… ${(controller.frameCount / 16000).toStringAsFixed(1)} seconds'
                      : controller.hasPendingCalibrationAudio
                      ? 'Ready to save · ${(controller.pendingCalibrationDuration.inMilliseconds / 1000).toStringAsFixed(1)} seconds'
                      : 'No unsaved test recording',
                  textAlign: TextAlign.center,
                ),
                if (controller.error != null)
                  Text(
                    controller.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (controller.hasPendingCalibrationAudio) ...[
                  const SizedBox(height: 16),
                  const Text('On-device analysis captured.'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : controller.discardPendingCalibration,
                          child: const Text('Discard'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'Saving…' : 'Save test sample'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                Text(
                  'Saved test samples (${calibration?.records.length ?? 0})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (calibration == null || calibration.records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('No accuracy samples saved yet.'),
                  )
                else
                  for (final record in calibration.records)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Al-Fātiḥah ${record.ayah} · ${record.label.title}',
                      ),
                      subtitle: Text(
                        '${(record.durationMilliseconds / 1000).toStringAsFixed(1)} seconds${record.note == null ? "" : " · ${record.note}"}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Delete recording',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteRecording(record),
                      ),
                    ),
                if (calibration != null && calibration.records.isNotEmpty)
                  OutlinedButton(
                    onPressed: _deleteAll,
                    child: const Text('Delete all accuracy samples'),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Each saved item contains a WAV plus recognition and alignment metadata. Nothing is uploaded.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AccuracyProgress extends StatelessWidget {
  const _AccuracyProgress({required this.records});

  final List<CalibrationRecord> records;

  @override
  Widget build(BuildContext context) {
    var careful = 0;
    var controlled = 0;
    for (var ayah = 1; ayah <= 7; ayah++) {
      final carefulForAyah = records
          .where(
            (item) =>
                item.ayah == ayah &&
                item.label == CalibrationLabel.carefulRecitation,
          )
          .length;
      careful += carefulForAyah > 3 ? 3 : carefulForAyah;
      if (records.any(
        (item) =>
            item.ayah == ayah &&
            item.label == CalibrationLabel.deliberatePronunciationChange,
      )) {
        controlled++;
      }
      if (records.any(
        (item) =>
            item.ayah == ayah && item.label == CalibrationLabel.skippedWord,
      )) {
        controlled++;
      }
    }
    final next = careful < 21
        ? 'Next: record a careful verse. The target is three examples for each verse.'
        : controlled < 14
        ? 'Next: record a known changed sound or skipped word and describe it.'
        : 'The minimum pilot set is complete and ready for threshold analysis.';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Local test set',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Careful recitations: $careful of 21'),
            Text('Known changes or skipped words: $controlled of 14'),
            const SizedBox(height: 10),
            Text(next),
          ],
        ),
      ),
    );
  }
}
