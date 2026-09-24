import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/audio/audio_capture.dart';
import 'core/audio/quran_reference_player.dart';
import 'core/calibration/calibration_repository.dart';
import 'core/progress/progress_repository.dart';
import 'core/quran/quran_repository.dart';
import 'core/settings/local_settings.dart';
import 'core/speech/quran_speech_engine.dart';
import 'features/recitation/recitation_controller.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['Prayer calculations · MAWAQIT / PrayTimes.org'],
      'Dart adaptation of mawaqit/prayer-times (640157265aaa4e71e33b8aa718f36f35fb99eb92).\n'
      'Original work: Hamid Zarrabi-Zadeh, Meezaan-ud-Din. https://praytimes.org\n'
      'https://github.com/mawaqit/prayer-times\n'
      'Modified: deterministic date-based Asr, missing-event safeguards.\n\n'
      '${await rootBundle.loadString('assets/licenses/mawaqit-prayer-times-lgpl.txt')}\n\n'
      '${await rootBundle.loadString('assets/licenses/gpl-3.0.txt')}',
    );
    yield LicenseEntryWithLineBreaks([
      'Rowwad Translation Center · QuranEnc.com',
    ], await rootBundle.loadString('assets/licenses/quranenc.txt'));
    yield LicenseEntryWithLineBreaks([
      'Qwen3.5-4B',
    ], await rootBundle.loadString('assets/licenses/qwen3.5.txt'));
    yield LicenseEntryWithLineBreaks([
      'llama.cpp',
    ], await rootBundle.loadString('assets/licenses/llama.cpp.txt'));
  });
  final preferences = SharedPreferencesAsync();
  final settings = LocalSettings(PreferencesSettingsStore(preferences));
  final progress = LocalProgressRepository(
    PreferencesProgressStore(preferences),
  );
  final calibration = LocalCalibrationRepository();
  final referencePlayer = QuranReferencePlayer();
  await settings.load();
  await progress.load();
  await calibration.load();
  final repository = await LocalQuranRepository.load();
  final engine = defaultTargetPlatform == TargetPlatform.iOS
      ? CoreMLQuranSpeechEngine()
      : OnnxQuranSpeechEngine();
  runApp(
    QuranTeacherApp(
      settings: settings,
      repository: repository,
      controller: RecitationController(
        audio: PlatformAudioCapture(),
        engine: engine,
        progress: progress,
        calibration: calibration,
      ),
      referencePlayer: referencePlayer,
    ),
  );
}
