import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/alignment/word_feedback_engine.dart';
import 'core/audio/quran_reference_player.dart';
import 'core/progress/progress_repository.dart';
import 'core/quran/quran_repository.dart';
import 'core/quran/bookmark_stop.dart';
import 'core/scoring/pronunciation_error.dart';
import 'core/settings/local_settings.dart';
import 'core/theme/app_theme.dart';
import 'core/tajwid/tajwid_rule_engine.dart';
import 'core/teacher/teacher_feedback_engine.dart';
import 'features/recitation/recitation_controller.dart';
import 'features/debug/debug_screen.dart';
import 'features/debug/calibration_screen.dart';
import 'features/dua/dua_screen.dart';
import 'features/hadith/hadith_screen.dart';
import 'features/ask/ask_screen.dart';
import 'features/prayer/prayer_screen.dart';
import 'features/prayer/qibla_screen.dart';
import 'features/prayer/prayer_teacher_screen.dart';
import 'core/ask/ask_engine.dart';
import 'core/ask/ask_library.dart';

const quranIndoPakFontFamily = 'QuranIndoPak';

// Keep the final waqf jeem with the verse medallion rather than letting the
// font's combining-mark placement hang beyond the last word's layout bounds.
final _endingJeem = RegExp(r'\u06DA(?=[\s\u200B-\u200F\uFEFF]*$)');

class QuranTeacherApp extends StatelessWidget {
  const QuranTeacherApp({
    super.key,
    required this.settings,
    required this.repository,
    required this.controller,
    required this.referencePlayer,
  });
  final LocalSettings settings;
  final QuranRepository repository;
  final RecitationController controller;
  final QuranReferencePlayer referencePlayer;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => MaterialApp(
      title: 'Rafiq Al-Huda',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(settings.colorTheme, Brightness.light),
      darkTheme: buildAppTheme(settings.colorTheme, Brightness.dark),
      themeMode: appThemeMode(settings.appearance),
      routes: {
        '/debug': (_) => DebugScreen(controller: controller),
        '/calibration': (_) =>
            CalibrationScreen(controller: controller, repository: repository),
      },
      home: settings.acknowledged
          ? ModuleDashboard(
              repository: repository,
              controller: controller,
              settings: settings,
              referencePlayer: referencePlayer,
            )
          : _OnboardingScreen(settings: settings),
    ),
  );
}

class ModuleDashboard extends StatelessWidget {
  const ModuleDashboard({
    super.key,
    required this.repository,
    required this.controller,
    required this.settings,
    required this.referencePlayer,
  });
  final QuranRepository repository;
  final RecitationController controller;
  final LocalSettings settings;
  final QuranReferencePlayer referencePlayer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Your learning space')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Learn. Reflect. Grow.',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Choose a module to begin.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            Card(
              child: ListTile(
                key: const ValueKey('module-prayer-teacher'),
                contentPadding: const EdgeInsets.all(24),
                leading: Icon(
                  Icons.menu_book_outlined,
                  size: 36,
                  color: scheme.primary,
                ),
                title: const Text(
                  'Prayer Teacher',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Learn the prayer, step by step.'),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PrayerTeacherScreen(
                      repository: repository,
                      settings: settings,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                key: const ValueKey('module-prayer'),
                contentPadding: const EdgeInsets.all(24),
                leading: Icon(
                  Icons.mosque_outlined,
                  size: 36,
                  color: scheme.primary,
                ),
                title: const Text(
                  'Prayer Times',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Your daily prayers. Calculated offline.'),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PrayerScreen(settings: settings),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: const ValueKey('module-qibla'),
                contentPadding: const EdgeInsets.all(24),
                leading: Icon(
                  Icons.explore_outlined,
                  size: 36,
                  color: scheme.primary,
                ),
                title: const Text(
                  'Qibla Compass',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => QiblaScreen(
                      location: settings.prayerConfiguration?.location,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: const ValueKey('module-quran'),
                contentPadding: const EdgeInsets.all(24),
                leading: Icon(
                  Icons.menu_book_rounded,
                  size: 36,
                  color: scheme.primary,
                ),
                title: const Text(
                  'Qur’an',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Read, listen and follow recitation'),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => RecitationScreen(
                      repository: repository,
                      controller: controller,
                      settings: settings,
                      referencePlayer: referencePlayer,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: const ValueKey('module-dua'),
                contentPadding: const EdgeInsets.all(24),
                leading: Icon(
                  Icons.favorite_outline_rounded,
                  size: 36,
                  color: scheme.primary,
                ),
                title: const Text(
                  'Duʿā',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Find a duʿā. Keep your favourites close.'),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        DuaScreen(repository: repository, settings: settings),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                key: const ValueKey('module-hadith'),
                contentPadding: const EdgeInsets.all(24),
                leading: Icon(
                  Icons.auto_stories_outlined,
                  size: 36,
                  color: scheme.primary,
                ),
                title: const Text(
                  'Hadith',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Explore collections, books and narrations.'),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => HadithScreen(settings: settings),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                key: const ValueKey('module-ask'),
                contentPadding: const EdgeInsets.all(24),
                leading: Icon(
                  Icons.question_answer_outlined,
                  size: 36,
                  color: scheme.primary,
                ),
                title: const Text(
                  'Ask Qur’an & Hadith',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Offline explanations with source passages'),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AskScreen(repository: repository),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingScreen extends StatelessWidget {
  const _OnboardingScreen({required this.settings});

  final LocalSettings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 46,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Rafiq Al-Huda',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Private, on-device Qur’an practice',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          const Text(
                            teacherDisclaimer,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, height: 1.45),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tajwīd feedback is limited to evidence the on-device model can support.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: settings.acknowledge,
                      child: const Text('I understand — Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RecitationScreen extends StatefulWidget {
  const RecitationScreen({
    super.key,
    required this.repository,
    required this.controller,
    required this.settings,
    required this.referencePlayer,
  });
  final QuranRepository repository;
  final RecitationController controller;
  final LocalSettings settings;
  final QuranReferencePlayer referencePlayer;
  @override
  State<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends State<RecitationScreen>
    with WidgetsBindingObserver {
  late int surah, ayah;
  bool _wasListening = false;
  bool _returningToDashboard = false;
  bool _changingListeningMode = false;
  bool _openingWrongPart = false;
  ({int wordIndex, String word, String message})? _wordExplanation;
  bool _resumeListeningOnNextVerse = false;
  int? _scheduledEndResultCount;
  int? _followedWordIndex;
  Timer? _endOfVerseTimer;
  final ScrollController _lessonScrollController = ScrollController();
  late List<GlobalKey> _wordKeys;

  @override
  void initState() {
    super.initState();
    final initialLocation = _locationAfterBookmark();
    surah = initialLocation.$1;
    ayah = initialLocation.$2;
    widget.controller.setFollowRecitation(
      widget.settings.followRecitation,
      widget.repository,
    );
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_controllerChanged);
    widget.referencePlayer.addListener(_playbackChanged);
    final initialAyah = widget.repository.getAyah(surah, ayah);
    _wordKeys = List.generate(initialAyah.words.length, (_) => GlobalKey());
    widget.controller.selectAyah(initialAyah);
  }

  (int, int) _locationAfterBookmark() {
    final bookmarkedSurah = widget.settings.bookmarkSurah;
    final bookmarkedAyah = widget.settings.bookmarkAyah;
    if (bookmarkedSurah == null || bookmarkedAyah == null) return (1, 1);

    final verseCount = widget.repository
        .getChapter(bookmarkedSurah)
        .versesCount;
    final validAyah = bookmarkedAyah.clamp(1, verseCount);
    if (validAyah < verseCount) return (bookmarkedSurah, validAyah + 1);
    if (bookmarkedSurah < 114) {
      return (
        bookmarkedSurah + 1,
        widget.repository.firstLessonAyah(bookmarkedSurah + 1),
      );
    }
    return (bookmarkedSurah, verseCount);
  }

  Future<void> _selectLocation(int nextSurah, int nextAyah) async {
    if (nextSurah < 1 ||
        nextSurah > 114 ||
        nextAyah < widget.repository.firstLessonAyah(nextSurah) ||
        nextAyah > widget.repository.getChapter(nextSurah).versesCount ||
        widget.controller.busy ||
        widget.controller.calibrationRecording ||
        widget.controller.hasPendingCalibrationAudio) {
      return;
    }
    if (!widget.controller.listening) await widget.referencePlayer.stop();
    if (!mounted) return;
    setState(() {
      surah = nextSurah;
      ayah = nextAyah;
      _wordExplanation = null;
      _wordKeys = List.generate(
        widget.repository.getAyah(nextSurah, nextAyah).words.length,
        (_) => GlobalKey(),
      );
      _followedWordIndex = null;
    });
    _endOfVerseTimer?.cancel();
    _scheduledEndResultCount = null;
    _resumeListeningOnNextVerse = false;
    final selected = widget.repository.getAyah(surah, ayah);
    if (widget.controller.listening) {
      widget.controller.navigateWhileListening(selected);
    } else {
      widget.controller.selectAyah(selected);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _lessonScrollController.hasClients) {
        _lessonScrollController.jumpTo(0);
      }
    });
  }

  Future<void> _selectAyah(int value) => _selectLocation(surah, value);

  void _controllerChanged() {
    if (_returningToDashboard) return;
    if (_openingWrongPart || widget.controller.practiceWordIndex != null) {
      _wasListening = widget.controller.listening;
      _endOfVerseTimer?.cancel();
      return;
    }
    final controller = widget.controller;
    if (controller.followRecitation &&
        controller.practiceWordIndex == null &&
        !controller.calibrationRecording &&
        !controller.hasPendingCalibrationAudio) {
      final location = controller.followedPosition;
      if (mounted &&
          controller.followPositionConfirmed &&
          location != null &&
          (surah != location.verse.surah || ayah != location.verse.ayah)) {
        setState(() {
          surah = location.verse.surah;
          ayah = location.verse.ayah;
          _wordKeys = List.generate(
            location.verse.words.length,
            (_) => GlobalKey(),
          );
          _followedWordIndex = null;
        });
        if (_lessonScrollController.hasClients) {
          _lessonScrollController.jumpTo(0);
        }
      }
      _endOfVerseTimer?.cancel();
      _scheduledEndResultCount = null;
      _wasListening = controller.listening;
      _followRecognizedWord();
      return;
    }
    _followRecognizedWord();
    _scheduleAutomaticFinish();
    // Accuracy-check recordings share the controller but must never trigger
    // normal lesson completion or automatic verse advancement.
    if (widget.controller.hasPendingCalibrationAudio) {
      _wasListening = widget.controller.listening;
      return;
    }
    final justFinished =
        _wasListening &&
        !widget.controller.listening &&
        widget.controller.utteranceFinalized;
    _wasListening = widget.controller.listening;
    if (!justFinished) return;
    final resumeListening = _resumeListeningOnNextVerse;
    _resumeListeningOnNextVerse = false;
    final completedAyah = ayah;
    final feedback = widget.controller.wordFeedback;
    final allAccepted =
        feedback.isNotEmpty &&
        feedback.every((item) => item.status == WordFeedbackStatus.accepted);
    if (widget.controller.needsVerseRetry ||
        (!allAccepted && !widget.controller.reachedEndOfExpectedSequence)) {
      return;
    }
    Future<void>.delayed(
      resumeListening ? Duration.zero : const Duration(milliseconds: 250),
      () async {
        if (!mounted ||
            ayah != completedAyah ||
            widget.controller.listening ||
            controller.needsVerseRetry) {
          return;
        }
        final verseCount = widget.repository.getChapter(surah).versesCount;
        var advanced = false;
        if (ayah < verseCount) {
          await _selectAyah(ayah + 1);
          advanced = true;
        } else if (surah < 114) {
          await _selectLocation(
            surah + 1,
            widget.repository.firstLessonAyah(surah + 1),
          );
          advanced = true;
        } else {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.check_circle_outline_rounded),
              title: const Text('Qur’an complete'),
              content: const Text('You reached the final verse.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Continue'),
                ),
              ],
            ),
          );
        }
        if (resumeListening && advanced && mounted) {
          await widget.controller.startMicrophone();
        }
      },
    );
  }

  void _followRecognizedWord() {
    if (!widget.controller.listening || !mounted) return;
    final feedback = widget.controller.wordFeedback;
    final current = feedback.indexWhere(
      (item) => item.status == WordFeedbackStatus.current,
    );
    _followWord(current);
  }

  void _playbackChanged() {
    final player = widget.referencePlayer;
    if (!player.playing) {
      _followedWordIndex = null;
      return;
    }
    _followWord(player.playingWordIndex ?? -1);
  }

  void _followWord(int current) {
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        current < 0 ||
        current == _followedWordIndex) {
      return;
    }
    _followedWordIndex = current;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || current >= _wordKeys.length) return;
      final context = _wordKeys[current].currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.42,
      );
    });
  }

  void _scheduleAutomaticFinish() {
    final controller = widget.controller;
    if (!controller.listening ||
        controller.practiceWordIndex != null ||
        controller.calibrationRecording ||
        controller.hasPendingCalibrationAudio ||
        controller.needsVerseRetry ||
        !controller.reachedEndOfExpectedSequence) {
      _endOfVerseTimer?.cancel();
      _scheduledEndResultCount = null;
      return;
    }
    final resultCount = controller.recognitionResults.length;
    if (_scheduledEndResultCount != null) return;
    _scheduledEndResultCount = resultCount;
    _endOfVerseTimer?.cancel();
    // Briefly debounce the completed alignment without forcing fast reciters
    // to pause for almost a second between verses.
    _endOfVerseTimer = Timer(const Duration(milliseconds: 200), () async {
      if (!mounted ||
          !controller.listening ||
          controller.needsVerseRetry ||
          !controller.reachedEndOfExpectedSequence) {
        return;
      }
      _scheduledEndResultCount = null;
      final verseCount = widget.repository.getChapter(surah).versesCount;
      if (ayah == verseCount && surah == 114) {
        await controller.stopMicrophone();
        return;
      }
      final nextSurah = ayah < verseCount ? surah : surah + 1;
      final nextAyah = ayah < verseCount
          ? ayah + 1
          : widget.repository.firstLessonAyah(nextSurah);
      final next = widget.repository.getAyah(nextSurah, nextAyah);
      // Set the view before notifying: any carried-over phonemes are followed
      // using the next verse's word keys. Capture/model state stays untouched.
      setState(() {
        surah = nextSurah;
        ayah = nextAyah;
        _wordKeys = List.generate(next.words.length, (_) => GlobalKey());
        _followedWordIndex = null;
      });
      if (_lessonScrollController.hasClients) _lessonScrollController.jumpTo(0);
      controller.continueWithAyah(next);
    });
  }

  Future<void> _retryWrongPart([int? wordIndex]) async {
    if (_openingWrongPart || widget.controller.busy) return;
    final target = widget.controller.wordFeedback
        .where(
          (item) =>
              item.status == WordFeedbackStatus.needsReview &&
              (wordIndex == null || item.word.index == wordIndex),
        )
        .firstOrNull;
    if (target == null) return;
    await _listenFromWord(target.word.index);
  }

  Future<void> _listenFromWord(int wordIndex) async {
    if (_openingWrongPart || widget.controller.busy) return;
    setState(() => _wordExplanation = null);
    _openingWrongPart = true;
    _endOfVerseTimer?.cancel();
    _resumeListeningOnNextVerse = false;
    try {
      await widget.referencePlayer.stop();
      await widget.controller.stopMicrophone();
      if (!mounted) return;
      widget.controller.prepareListeningFromWord(wordIndex);
      _followedWordIndex = null;
      _followWord(widget.controller.listeningFromWord ?? wordIndex);
      await widget.controller.startMicrophone();
    } finally {
      _openingWrongPart = false;
      _wasListening = widget.controller.listening;
      _scheduledEndResultCount = null;
    }
  }

  Future<void> _playWordWithFeedback(QuranAyah verse, int wordIndex) async {
    if (_openingWrongPart || widget.controller.busy) return;
    _openingWrongPart = true;
    _endOfVerseTimer?.cancel();
    _resumeListeningOnNextVerse = false;
    try {
      // Reference audio must not feed back into the student's microphone.
      await widget.controller.stopMicrophone();
      await widget.referencePlayer.stop();
      if (!mounted || surah != verse.surah || ayah != verse.ayah) return;
      final group = verse.groupForWord(wordIndex);
      final start = group?.wordStart ?? wordIndex;
      final end = group?.wordEnd ?? wordIndex + 1;
      final findings = widget.controller.pronunciationErrors.where(
        (finding) => finding.wordIndex >= start && finding.wordIndex < end,
      );
      final tajwid = widget.controller.tajwidFindings.where(
        (finding) =>
            finding.wordIndex >= start &&
            finding.wordIndex < end &&
            finding.assessment == TajwidAssessment.needsPractice,
      );
      final messages = <String>{
        for (final finding in tajwid)
          'Doubled sound (shaddah)\nExpected sound: ${finding.expectedPhoneme}\nHeard closer to: ${finding.detectedPhoneme ?? "not clear"}\n\n${finding.guidance}',
        for (final finding in findings)
          const DeterministicTeacherFeedbackEngine().explain(finding),
      };
      final explanation = messages.isEmpty
          ? widget.controller.followRecitation
                ? 'Follow mode does not check pronunciation.'
                : 'The app does not have a reliable sound-level explanation for this word yet. A warning can also mean the recording was unclear.\n\nTap Listen from here, recite the word clearly, then double-tap it again to review. This does not mean your pronunciation was correct or incorrect.'
          : messages.join('\n\n');
      setState(
        () => _wordExplanation = (
          wordIndex: start,
          word: verse.pronunciationWord(start).displayText,
          message: end - start > 1
              ? 'These words share a sound, so feedback applies to the phrase.\n\n$explanation'
              : explanation,
        ),
      );
      final audio = verse.referenceAudio;
      if (audio != null) {
        if (end - start > 1) {
          await widget.referencePlayer.playWords(audio, start, end);
        } else {
          await widget.referencePlayer.playWord(audio, start);
        }
      }
    } finally {
      _openingWrongPart = false;
      _wasListening = false;
      _scheduledEndResultCount = null;
    }
  }

  Future<void> _openWordPractice(QuranWord word, {bool repair = false}) async {
    if (widget.controller.expectedAyah?.supportsPronunciation == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Focused scoring is unavailable here because the recited sounds join across word boundaries. You can still tap the word to listen.',
          ),
        ),
      );
      return;
    }
    await widget.referencePlayer.stop();
    if (!mounted) return;
    if (repair) {
      widget.controller.beginWrongPartPractice(word.index);
    } else {
      widget.controller.beginWordPractice(word.index);
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => WordPracticeScreen(
          controller: widget.controller,
          referencePlayer: widget.referencePlayer,
        ),
      ),
    );
    await widget.referencePlayer.stop();
    if (widget.controller.listening || widget.controller.recognitionActive) {
      await widget.controller.stopMicrophone();
    }
    if (repair) {
      widget.controller.endWrongPartPractice();
    } else {
      widget.controller.endWordPractice();
    }
  }

  Future<void> _openPracticeAt(
    int targetSurah,
    int targetAyah,
    int wordIndex,
  ) async {
    if (targetSurah != surah || targetAyah != ayah) {
      await _selectLocation(targetSurah, targetAyah);
    }
    if (!mounted || surah != targetSurah || ayah != targetAyah) return;
    final words = widget.repository.getAyah(targetSurah, targetAyah).words;
    if (wordIndex < 0 || wordIndex >= words.length) return;
    await _openWordPractice(words[wordIndex]);
  }

  Future<void> _previous() async {
    if (ayah > widget.repository.firstLessonAyah(surah)) {
      return _selectAyah(ayah - 1);
    }
    if (surah > 1) {
      final previous = widget.repository.getChapter(surah - 1);
      return _selectLocation(previous.number, previous.versesCount);
    }
  }

  Future<void> _next() async {
    final chapter = widget.repository.getChapter(surah);
    if (ayah < chapter.versesCount) return _selectAyah(ayah + 1);
    if (surah < 114) {
      return _selectLocation(
        surah + 1,
        widget.repository.firstLessonAyah(surah + 1),
      );
    }
  }

  Future<void> _chooseLocation() async {
    if (widget.controller.listening || widget.controller.busy) return;
    final selected = await showDialog<(int, int)>(
      context: context,
      builder: (_) => _LocationDialog(
        repository: widget.repository,
        referencePlayer: widget.referencePlayer,
        surah: surah,
        ayah: ayah,
      ),
    );
    if (selected != null && mounted) {
      await _selectLocation(selected.$1, selected.$2);
    }
  }

  Future<void> _bookmarkCurrent() async {
    await widget.settings.setBookmark(surah, ayah);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bookmark saved. Next time starts after this verse.'),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(widget.controller.stopMicrophone());
      unawaited(widget.referencePlayer.stop());
    }
  }

  @override
  void dispose() {
    _endOfVerseTimer?.cancel();
    _lessonScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_controllerChanged);
    if (!_returningToDashboard) unawaited(widget.controller.stopMicrophone());
    widget.referencePlayer.removeListener(_playbackChanged);
    unawaited(widget.referencePlayer.stop());
    super.dispose();
  }

  Future<void> _toggleListening(bool follow) async {
    if (widget.controller.busy || _changingListeningMode) return;
    setState(() => _changingListeningMode = true);
    setState(() => _wordExplanation = null);
    try {
      _resumeListeningOnNextVerse = false;
      await widget.referencePlayer.stop();
      final stopOnly =
          widget.controller.listening &&
          widget.controller.followRecitation == follow;
      if (widget.controller.listening) {
        await widget.controller.stopMicrophone();
      }
      if (!mounted || stopOnly) return;
      widget.controller.setFollowRecitation(follow, widget.repository);
      await widget.settings.setFollowRecitation(follow);
      if (mounted) await widget.controller.startMicrophone();
    } finally {
      if (mounted) setState(() => _changingListeningMode = false);
    }
  }

  Future<void> _returnToDashboard() async {
    if (_returningToDashboard) return;
    _returningToDashboard = true;
    _endOfVerseTimer?.cancel();
    _resumeListeningOnNextVerse = false;
    await widget.controller.stopMicrophone();
    await widget.referencePlayer.stop();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleVersePlayback(QuranAyah current) async {
    if (widget.controller.listening || widget.controller.busy) return;
    setState(() => _wordExplanation = null);
    if (widget.referencePlayer.playing || widget.referencePlayer.loading) {
      await widget.referencePlayer.stop();
    } else if (current.referenceAudio != null) {
      await widget.referencePlayer.playVerse(
        current.referenceAudio!,
        nextVerse: _advanceReferencePlayback,
      );
    }
  }

  QuranReferenceAudio? _advanceReferencePlayback() {
    if (!mounted ||
        _returningToDashboard ||
        ModalRoute.of(context)?.isCurrent != true ||
        widget.controller.listening ||
        widget.controller.busy) {
      return null;
    }
    final chapter = widget.repository.getChapter(surah);
    if (surah == 114 && ayah == chapter.versesCount) return null;
    final nextSurah = ayah < chapter.versesCount ? surah : surah + 1;
    final nextAyah = ayah < chapter.versesCount
        ? ayah + 1
        : widget.repository.firstLessonAyah(nextSurah);
    final next = widget.repository.getAyah(nextSurah, nextAyah);
    if (next.referenceAudio == null) return null;
    setState(() {
      surah = nextSurah;
      ayah = nextAyah;
      _wordKeys = List.generate(next.words.length, (_) => GlobalKey());
      _followedWordIndex = null;
    });
    widget.controller.selectAyah(next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _lessonScrollController.hasClients) {
        _lessonScrollController.jumpTo(0);
      }
    });
    return next.referenceAudio;
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.repository.getChapter(surah);
    final current = widget.repository.getAyah(surah, ayah);
    final bookmarkStop = ayah > 0
        ? BookmarkStop.forVerse(widget.repository, surah, ayah)
        : null;
    final hasEndingJeem =
        ayah > 0 && _endingJeem.hasMatch(current.words.last.displayText);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Return to dashboard',
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _returnToDashboard,
        ),
        title: Tooltip(
          message: 'Go to surah and verse',
          child: GestureDetector(
            onTap: _chooseLocation,
            onLongPress: () => Navigator.pushNamed(context, '/debug'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chapter.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        ayah == 0
                            ? 'Bismillāh'
                            : 'Verse $ayah of ${chapter.versesCount}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more_rounded, size: 18),
              ],
            ),
          ),
        ),
        actions: [
          if (widget.controller.progress != null)
            IconButton(
              tooltip: 'Practice progress',
              icon: const Icon(Icons.insights_outlined),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ProgressScreen(
                    progress: widget.controller.progress!,
                    repository: widget.repository,
                    onPracticeWord: _openPracticeAt,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Settings and model information',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(
                  settings: widget.settings,
                  controller: widget.controller,
                  referencePlayer: widget.referencePlayer,
                  repository: widget.repository,
                  onPracticeWord: _openPracticeAt,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListenableBuilder(
              listenable: Listenable.merge([
                widget.controller,
                widget.referencePlayer,
                widget.settings,
              ]),
              builder: (context, _) {
                final feedback = widget.controller.wordFeedback;
                final tajwidReviews = widget.controller.tajwidFindings.where(
                  (finding) =>
                      finding.assessment == TajwidAssessment.needsPractice,
                );
                final scheme = Theme.of(context).colorScheme;
                return ListView(
                  controller: _lessonScrollController,
                  padding: EdgeInsets.fromLTRB(
                    18,
                    10,
                    18,
                    _wordExplanation != null
                        ? MediaQuery.sizeOf(context).height * .45 +
                              MediaQuery.paddingOf(context).bottom +
                              64
                        : widget.controller.needsVerseRetry
                        ? 180
                        : 96,
                  ),
                  children: [
                    for (final finding in tajwidReviews)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.hearing_rounded),
                          title: Text('Shaddah · ${finding.word}'),
                          subtitle: Text(finding.guidance),
                          trailing: widget.controller.listening
                              ? null
                              : const Icon(Icons.chevron_right),
                          onTap: widget.controller.busy
                              ? null
                              : () => _retryWrongPart(finding.wordIndex),
                        ),
                      ),
                    if (widget.controller.followRecitation)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          !widget.controller.listening
                              ? 'Follow recitation · experimental'
                              : widget.controller.followPositionVisible
                              ? current.exactWordMapping
                                    ? 'Following recitation'
                                    : 'Following · approximate word position'
                              : 'Listening · finding your place…',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.alphaBlend(
                              scheme.primary.withValues(alpha: .075),
                              scheme.surfaceContainerLow,
                            ),
                            scheme.surfaceContainerLowest,
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
                        child: Column(
                          children: [
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: LayoutBuilder(
                                builder: (context, available) => Wrap(
                                  spacing: 10,
                                  runSpacing: 18,
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.start,
                                  children: [
                                    for (final word in current.words)
                                      Builder(
                                        builder: (context) {
                                          final displayText =
                                              hasEndingJeem &&
                                                  word.index ==
                                                      current.words.last.index
                                              ? word.displayText.replaceFirst(
                                                  _endingJeem,
                                                  '',
                                                )
                                              : word.displayText;
                                          final arabicStyle = TextStyle(
                                            fontFamily: quranIndoPakFontFamily,
                                            fontSize:
                                                widget.settings.arabicSize,
                                            height: 2,
                                          );
                                          final measure = TextPainter(
                                            text: TextSpan(
                                              text: displayText,
                                              style: arabicStyle,
                                            ),
                                            textDirection: TextDirection.rtl,
                                            textScaler: MediaQuery.textScalerOf(
                                              context,
                                            ),
                                            maxLines: 1,
                                          )..layout();
                                          final wordWidth = (measure.width + 4)
                                              .clamp(
                                                100.0,
                                                available.maxWidth - 10,
                                              );
                                          measure.dispose();
                                          final status =
                                              feedback.length > word.index
                                              ? feedback[word.index].status
                                              : WordFeedbackStatus.unread;
                                          final isPlaying =
                                              widget
                                                  .referencePlayer
                                                  .playingWordIndex ==
                                              word.index;
                                          final isHeld =
                                              widget
                                                  .controller
                                                  .followRecitation &&
                                              widget
                                                  .controller
                                                  .followPositionHeld &&
                                              status ==
                                                  WordFeedbackStatus.current;
                                          return Semantics(
                                            button: true,
                                            label:
                                                'Listen from ${word.displayText}',
                                            hint: 'Double tap to hear the reference and review feedback',
                                            child: GestureDetector(
                                              onTap: widget.controller.busy
                                                  ? null
                                                  : () => _listenFromWord(
                                                      word.index,
                                                    ),
                                              onDoubleTap:
                                                  widget.controller.busy
                                                  ? null
                                                  : () => _playWordWithFeedback(
                                                      current,
                                                      word.index,
                                                    ),
                                              onLongPress:
                                                  widget.controller.listening ||
                                                      widget.controller.busy
                                                  ? null
                                                  : () =>
                                                        _openWordPractice(word),
                                              child: AnimatedContainer(
                                                key: _wordKeys[word.index],
                                                duration: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isPlaying
                                                      ? scheme.primary
                                                            .withValues(
                                                              alpha: 0.16,
                                                            )
                                                      : isHeld
                                                      ? scheme.primary
                                                            .withValues(
                                                              alpha: .045,
                                                            )
                                                      : _wordBackground(
                                                          context,
                                                          status,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: SizedBox(
                                                  width: wordWidth,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Text(
                                                          displayText,
                                                          maxLines: 1,
                                                          softWrap: false,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            fontFamily:
                                                                quranIndoPakFontFamily,
                                                            fontSize: widget
                                                                .settings
                                                                .arabicSize,
                                                            height: 2.0,
                                                            decoration:
                                                                status ==
                                                                    WordFeedbackStatus
                                                                        .needsReview
                                                                ? TextDecoration
                                                                      .underline
                                                                : TextDecoration
                                                                      .none,
                                                            decorationColor:
                                                                _wordColor(
                                                                  context,
                                                                  WordFeedbackStatus
                                                                      .needsReview,
                                                                ),
                                                            decorationThickness:
                                                                2,
                                                            color: isHeld
                                                                ? Color.lerp(
                                                                    scheme
                                                                        .onSurface,
                                                                    scheme
                                                                        .primary,
                                                                    .35,
                                                                  )
                                                                : _wordColor(
                                                                    context,
                                                                    status,
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                      Directionality(
                                                        textDirection:
                                                            TextDirection.ltr,
                                                        child: Text(
                                                          word.english,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            height: 1.25,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: scheme
                                                                .onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    if (ayah > 0)
                                      SizedBox(
                                        height:
                                            MediaQuery.textScalerOf(context)
                                                .scale(
                                                  widget.settings.arabicSize,
                                                ) *
                                            2,
                                        child: Center(
                                          widthFactor: 1,
                                          child: Semantics(
                                            label: 'End of verse $ayah',
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                if (hasEndingJeem)
                                                  Positioned(
                                                    left: 0,
                                                    right: 0,
                                                    bottom:
                                                        widget
                                                                .settings
                                                                .arabicSize *
                                                            .72 +
                                                        3,
                                                    child: Text(
                                                      'ج',
                                                      textAlign:
                                                          TextAlign.center,
                                                      textDirection:
                                                          TextDirection.rtl,
                                                      style: TextStyle(
                                                        fontSize:
                                                            widget
                                                                .settings
                                                                .arabicSize *
                                                            .35,
                                                        height: 1,
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ),
                                                Container(
                                                  width:
                                                      widget
                                                          .settings
                                                          .arabicSize *
                                                      .72,
                                                  height:
                                                      widget
                                                          .settings
                                                          .arabicSize *
                                                      .72,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                      width: 1.6,
                                                    ),
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    child: FittedBox(
                                                      child: Text(
                                                        _verseMark(ayah),
                                                        textDirection:
                                                            TextDirection.ltr,
                                                        style: TextStyle(
                                                          fontSize:
                                                              widget
                                                                  .settings
                                                                  .arabicSize *
                                                              .45,
                                                          height: 1.15,
                                                          color: scheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (ayah > 0) ...[
                              const SizedBox(height: 18),
                              OutlinedButton.icon(
                                key: const ValueKey('verse-bookmark'),
                                style: bookmarkStop!.isGoodStop
                                    ? null
                                    : OutlinedButton.styleFrom(
                                        foregroundColor: scheme.error,
                                        backgroundColor: scheme.errorContainer,
                                        disabledForegroundColor: scheme.error,
                                        disabledBackgroundColor:
                                            scheme.errorContainer,
                                        side: BorderSide(color: scheme.error),
                                      ),
                                onPressed:
                                    widget.settings.isBookmarked(surah, ayah)
                                    ? null
                                    : _bookmarkCurrent,
                                icon: Icon(
                                  widget.settings.isBookmarked(surah, ayah)
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                ),
                                label: Text(
                                  widget.settings.isBookmarked(surah, ayah)
                                      ? 'Bookmarked'
                                      : 'Bookmark this verse',
                                ),
                              ),
                              if (!bookmarkStop.isGoodStop)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Not good stopping point',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: scheme.error,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '${bookmarkStop.remaining} ${bookmarkStop.remaining == 1 ? 'verse' : 'verses'} to next good stopping point · $surah:${bookmarkStop.next}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        value: bookmarkStop.progress,
                                        semanticsLabel: 'Progress to next good stopping point',
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Card(
                      key: ValueKey('verse-ask-$surah-$ayah'),
                      child: ExpansionTile(
                        title: const Text('Ask AI about this verse'),
                        leading: const Icon(Icons.question_answer_outlined),
                        childrenPadding: const EdgeInsets.all(16),
                        children: [
                          AskScreen(
                            inline: true,
                            repository: widget.repository,
                            selected: AskSource.quran(
                              ayah == 0
                                  ? widget.repository.getAyah(1, 1)
                                  : current,
                            ),
                            beforeAsk: () async {
                              await widget.controller.stopMicrophone();
                              await widget.referencePlayer.stop();
                            },
                          ),
                        ],
                      ),
                    ),
                    if (current.sajdahNumber != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: const ListTile(
                          leading: Icon(Icons.mosque_outlined),
                          title: Text('Sajdah verse'),
                          subtitle: Text(
                            'Perform sajdah after reciting this verse.',
                          ),
                        ),
                      ),
                    ],
                    if (widget.controller.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          widget.controller.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (widget.controller.recognitionError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Recognition unavailable: ${widget.controller.recognitionError}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      bottomSheet: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => _wordExplanation != null
            ? SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .45,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _wordExplanation!.word,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  fontFamily: quranIndoPakFontFamily,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close word feedback',
                              onPressed: () =>
                                  setState(() => _wordExplanation = null),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        Text(
                          _wordExplanation!.message,
                          key: const ValueKey('word-feedback-explanation'),
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontSize: 18, height: 1.45),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: widget.controller.busy
                              ? null
                              : () => _listenFromWord(
                                  _wordExplanation!.wordIndex,
                                ),
                          icon: const Icon(Icons.mic),
                          label: const Text('Listen from here'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : widget.controller.needsVerseRetry
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: widget.controller.busy
                            ? null
                            : _retryWrongPart,
                        icon: const Icon(Icons.record_voice_over_rounded),
                        label: const Text('Retry wrong part'),
                      ),
                      if (widget.controller.listening)
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('Needs practice · Retry verse'),
                          onPressed: () {
                            _endOfVerseTimer?.cancel();
                            _scheduledEndResultCount = null;
                            _followedWordIndex = null;
                            widget.controller.navigateWhileListening(current);
                            if (_lessonScrollController.hasClients) {
                              _lessonScrollController.jumpTo(0);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            widget.controller,
            widget.referencePlayer,
          ]),
          builder: (context, _) => BottomAppBar(
            height:
                78 +
                (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0, 48),
            child: Row(
              children: [
                _BottomControl(
                  icon: Icons.arrow_back_ios_new_rounded,
                  label: 'Back',
                  onPressed:
                      !(surah == 1 && ayah == 1) &&
                          !widget.controller.calibrationRecording &&
                          !widget.controller.hasPendingCalibrationAudio &&
                          !widget.controller.busy
                      ? _previous
                      : null,
                ),
                for (final follow in [true, false])
                  _BottomControl(
                    icon:
                        widget.controller.listening &&
                            widget.controller.followRecitation == follow
                        ? Icons.stop_circle_outlined
                        : follow
                        ? Icons.hearing_rounded
                        : Icons.mic_rounded,
                    label:
                        widget.controller.listening &&
                            widget.controller.followRecitation == follow
                        ? 'Stop'
                        : follow
                        ? 'Follow'
                        : 'Listen',
                    selected:
                        widget.controller.listening &&
                        widget.controller.followRecitation == follow,
                    onPressed: widget.controller.busy || _changingListeningMode
                        ? null
                        : () => _toggleListening(follow),
                  ),
                _BottomControl(
                  icon: widget.referencePlayer.playing
                      ? Icons.stop_circle_outlined
                      : widget.referencePlayer.loading
                      ? Icons.downloading_rounded
                      : Icons.play_circle_outline_rounded,
                  label: widget.referencePlayer.playing
                      ? 'Stop'
                      : widget.referencePlayer.loading
                      ? 'Cancel'
                      : 'Play',
                  selected:
                      widget.referencePlayer.playing ||
                      widget.referencePlayer.loading,
                  onPressed:
                      widget.controller.listening || widget.controller.busy
                      ? null
                      : () => _toggleVersePlayback(current),
                ),
                _BottomControl(
                  icon: Icons.arrow_forward_ios_rounded,
                  label: 'Forward',
                  onPressed:
                      !(surah == 114 && ayah == chapter.versesCount) &&
                          !widget.controller.calibrationRecording &&
                          !widget.controller.hasPendingCalibrationAudio &&
                          !widget.controller.busy
                      ? _next
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _verseMark(int value) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final number = value
        .toString()
        .split('')
        .map((d) => digits[int.parse(d)])
        .join();
    return number;
  }

  Color _wordColor(BuildContext context, WordFeedbackStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (status) {
      WordFeedbackStatus.unread ||
      WordFeedbackStatus.uncertain => scheme.onSurfaceVariant,
      WordFeedbackStatus.current => scheme.primary,
      WordFeedbackStatus.accepted =>
        dark ? const Color(0xff73D6A2) : const Color(0xff11734A),
      WordFeedbackStatus.needsReview =>
        dark ? const Color(0xffFFD078) : const Color(0xff875A00),
    };
  }

  Color _wordBackground(BuildContext context, WordFeedbackStatus status) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      WordFeedbackStatus.unread ||
      WordFeedbackStatus.uncertain => Colors.transparent,
      WordFeedbackStatus.current => scheme.primary.withValues(alpha: 0.11),
      WordFeedbackStatus.accepted => const Color(
        0xff28A86B,
      ).withValues(alpha: 0.12),
      WordFeedbackStatus.needsReview => const Color(
        0xffD89A00,
      ).withValues(alpha: 0.16),
    };
  }
}

class _LocationDialog extends StatefulWidget {
  const _LocationDialog({
    required this.repository,
    required this.referencePlayer,
    required this.surah,
    required this.ayah,
  });
  final QuranRepository repository;
  final QuranReferencePlayer referencePlayer;
  final int surah, ayah;
  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  late int surah = widget.surah;
  late final TextEditingController verseInput = TextEditingController(
    text: '${widget.ayah}',
  );
  String? verseError;

  @override
  void dispose() {
    verseInput.dispose();
    super.dispose();
  }

  void _go() {
    final verse = int.tryParse(verseInput.text);
    final first = widget.repository.firstLessonAyah(surah);
    final last = widget.repository.getChapter(surah).versesCount;
    if (verse == null || verse < first || verse > last) {
      setState(() => verseError = 'Enter a number from $first to $last');
      return;
    }
    Navigator.pop(context, (surah, verse));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Go to surah and verse'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: surah,
              isExpanded: true,
              menuMaxHeight: 360,
              decoration: const InputDecoration(labelText: 'Surah'),
              items: [
                for (final chapter in widget.repository.chapters)
                  DropdownMenuItem(
                    value: chapter.number,
                    child: Text(
                      '${chapter.number}. ${chapter.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    surah = value;
                    verseInput.text =
                        '${widget.repository.firstLessonAyah(value)}';
                    verseError = null;
                  });
                }
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: verseInput,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.go,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: InputDecoration(
                labelText: 'Verse number',
                helperText:
                    '1–${widget.repository.getChapter(surah).versesCount}${widget.repository.needsOpening(surah) ? ' · 0 for Bismillāh' : ''}',
                errorText: verseError,
              ),
              onTap: () => verseInput.selection = TextSelection(
                baseOffset: 0,
                extentOffset: verseInput.text.length,
              ),
              onChanged: (_) {
                if (verseError != null) setState(() => verseError = null);
              },
              onSubmitted: (_) => _go(),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () async {
          final selected = await Navigator.push<int>(
            context,
            MaterialPageRoute<int>(
              builder: (_) => SurahLibraryScreen(
                repository: widget.repository,
                currentSurah: surah,
                referencePlayer: widget.referencePlayer,
              ),
            ),
          );
          if (selected != null && context.mounted) {
            Navigator.pop(context, (
              selected,
              widget.repository.firstLessonAyah(selected),
            ));
          }
        },
        child: const Text('Browse & downloads'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _go, child: const Text('Go')),
    ],
  );
}

class _BottomControl extends StatelessWidget {
  const _BottomControl({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: onPressed == null
                    ? Theme.of(context).disabledColor
                    : selected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    color: onPressed == null
                        ? Theme.of(context).disabledColor
                        : selected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : null,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SurahLibraryScreen extends StatefulWidget {
  const SurahLibraryScreen({
    super.key,
    required this.repository,
    required this.currentSurah,
    required this.referencePlayer,
  });

  final QuranRepository repository;
  final int currentSurah;
  final QuranReferencePlayer referencePlayer;

  @override
  State<SurahLibraryScreen> createState() => _SurahLibraryScreenState();
}

class _SurahLibraryScreenState extends State<SurahLibraryScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final chapters = widget.repository.chapters.where((chapter) {
      return normalized.isEmpty ||
          chapter.number.toString() == normalized ||
          chapter.name.toLowerCase().contains(normalized) ||
          chapter.simpleName.toLowerCase().contains(normalized) ||
          chapter.translatedName.toLowerCase().contains(normalized) ||
          chapter.arabicName.contains(query.trim());
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Qur’an')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  hintText: 'Search surahs',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.referencePlayer,
                builder: (context, _) => ListView.builder(
                  itemCount: chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    final isCurrent = chapter.number == widget.currentSurah;
                    return ListTile(
                      selected: isCurrent,
                      leading: CircleAvatar(child: Text('${chapter.number}')),
                      title: Text(chapter.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chapter.arabicName,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontFamily: quranIndoPakFontFamily,
                              fontSize: 24,
                              height: 1.7,
                            ),
                          ),
                          Text(
                            '${chapter.translatedName} · ${chapter.versesCount} verses',
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        tooltip: 'Download this surah for offline audio',
                        onPressed: widget.referencePlayer.downloading
                            ? null
                            : () => widget.referencePlayer.downloadSurah(
                                widget.repository.getSurah(chapter.number),
                              ),
                        icon: const Icon(Icons.download_for_offline_outlined),
                      ),
                      onTap: () => Navigator.pop(context, chapter.number),
                    );
                  },
                ),
              ),
            ),
            if (widget.referencePlayer.downloading)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: widget.referencePlayer.downloadTotal == 0
                          ? null
                          : widget.referencePlayer.downloadCompleted /
                                widget.referencePlayer.downloadTotal,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Saving audio ${widget.referencePlayer.downloadCompleted} of ${widget.referencePlayer.downloadTotal}',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WordPracticeScreen extends StatefulWidget {
  const WordPracticeScreen({
    super.key,
    required this.controller,
    required this.referencePlayer,
  });

  final RecitationController controller;
  final QuranReferencePlayer referencePlayer;

  @override
  State<WordPracticeScreen> createState() => _WordPracticeScreenState();
}

class _WordPracticeScreenState extends State<WordPracticeScreen> {
  RecitationController get controller => widget.controller;

  Future<void> _listen(double rate) async {
    if (controller.listening || controller.busy) return;
    final ayah = controller.expectedAyah!;
    final audio = ayah.referenceAudio;
    final wordIndex = controller.practiceWordIndex;
    if (audio == null || wordIndex == null) return;
    final group = ayah.groupForWord(wordIndex);
    if (group != null && group.wordEnd - group.wordStart > 1) {
      await widget.referencePlayer.playWords(
        audio,
        group.wordStart,
        group.wordEnd,
        rate: rate,
      );
    } else {
      await widget.referencePlayer.playWord(audio, wordIndex, rate: rate);
    }
  }

  Future<void> _toggleAttempt() async {
    if (controller.busy) return;
    await widget.referencePlayer.stop();
    if (controller.listening) {
      await controller.stopMicrophone();
    } else {
      await controller.startMicrophone();
    }
  }

  @override
  void dispose() {
    unawaited(widget.referencePlayer.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        (controller.expectedAyah
                            ?.groupForWord(controller.practiceWordIndex ?? 0)
                            ?.wordEnd ??
                        0) -
                    (controller.expectedAyah
                            ?.groupForWord(controller.practiceWordIndex ?? 0)
                            ?.wordStart ??
                        0) >
                1
            ? 'Phrase practice'
            : 'Word practice',
      ),
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([controller, widget.referencePlayer]),
        builder: (context, _) {
          // The outgoing route can rebuild during its pop animation after
          // the verse controller has already restored the parent session.
          if (controller.practiceWordIndex == null) {
            return const SizedBox.shrink();
          }
          final ayah = controller.expectedAyah!;
          final word = ayah.pronunciationWord(controller.practiceWordIndex!);
          final group = ayah.groupForWord(controller.practiceWordIndex!);
          final joined = group != null && group.wordEnd - group.wordStart > 1;
          final feedback = controller.practiceFeedback;
          final finding = controller.pronunciationErrors.firstOrNull;
          final tajwidFinding = controller.tajwidFindings
              .where(
                (item) => item.assessment == TajwidAssessment.needsPractice,
              )
              .firstOrNull;
          final tajwidRules = DeterministicTajwidRuleEngine.rulesForWord(word);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  word.displayText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: quranIndoPakFontFamily,
                    fontSize: 52,
                    height: 2.1,
                    decoration:
                        feedback?.status == WordFeedbackStatus.needsReview
                        ? TextDecoration.underline
                        : TextDecoration.none,
                    decorationColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xffFFD078)
                        : const Color(0xff875A00),
                    decorationThickness: 2,
                  ),
                ),
              ),
              Text(
                word.english,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 18),
              if (joined)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'These words share a joined sound. Recite them together; feedback applies to the phrase, not one letter.',
                  ),
                ),
              if (tajwidRules.isNotEmpty) ...[
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (tajwidRules.contains(TajwidRuleType.shaddah))
                      const Chip(label: Text('Shaddah · doubled sound')),
                    if (tajwidRules.contains(TajwidRuleType.madd))
                      const Chip(label: Text('Madd · length not graded')),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: controller.listening || controller.busy
                          ? null
                          : () => _listen(1),
                      icon: const Icon(Icons.volume_up_outlined),
                      label: const Text('Listen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.listening || controller.busy
                          ? null
                          : () => _listen(0.72),
                      icon: const Icon(Icons.slow_motion_video_rounded),
                      label: const Text('Listen slowly'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (controller.listening ||
                  controller.practiceAttempts.isNotEmpty) ...[
                Text(
                  _practiceStatus(controller, feedback?.status),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
              ],
              if (finding != null) ...[
                const SizedBox(height: 20),
                Text(
                  _findingText(finding),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
              ],
              if (tajwidFinding != null) ...[
                const SizedBox(height: 12),
                Text(
                  tajwidFinding.guidance,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: controller.busy ? null : _toggleAttempt,
                icon: Icon(controller.listening ? Icons.stop : Icons.mic),
                label: Text(
                  controller.listening ? 'Finish attempt' : 'Try again',
                ),
              ),
              if (controller.practiceAttempts.isNotEmpty) ...[
                if (controller.repairingWrongPart && !controller.listening)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Return to verse'),
                  ),
                const SizedBox(height: 28),
                Text(
                  'Attempts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final attempt in controller.practiceAttempts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Attempt ${attempt.number}'),
                    subtitle: Text(_attemptLabel(attempt.status)),
                  ),
              ],
            ],
          );
        },
      ),
    ),
  );

  static String _practiceStatus(
    RecitationController controller,
    WordFeedbackStatus? status,
  ) {
    if (controller.listening) return 'Listening…';
    return _attemptLabel(status ?? WordFeedbackStatus.uncertain);
  }

  static String _attemptLabel(WordFeedbackStatus status) => switch (status) {
    WordFeedbackStatus.accepted => 'Strong phoneme match',
    WordFeedbackStatus.needsReview => 'Needs practice',
    WordFeedbackStatus.current => 'Still listening',
    WordFeedbackStatus.unread ||
    WordFeedbackStatus.uncertain => 'Not enough confidence — try again',
  };

  static String _findingText(PronunciationError finding) {
    return switch (finding.type) {
      PronunciationErrorType.substitution =>
        finding.expectedPhoneme != null && finding.detectedPhoneme != null
            ? finding.evidenceStatus == EvidenceStatus.confirmed
                  ? 'Expected ${finding.expectedPhoneme}. It sounded closer to ${finding.detectedPhoneme}. Listen once, then try again.'
                  : 'The expected ${finding.expectedPhoneme} may have sounded closer to ${finding.detectedPhoneme}. Listen and try again.'
            : 'A sound was heard differently. Try the word again slowly and clearly.',
      PronunciationErrorType.deletion =>
        'Part of the word may not have been heard clearly. Try once more.',
      PronunciationErrorType.insertion => 'An extra sound may have been heard. Try the word again without rushing.',
      PronunciationErrorType.repeatedPhoneme =>
        'A sound may have been repeated. Try the word once more.',
      PronunciationErrorType.skippedWord =>
        'The word may have been skipped or the attempt ended early.',
      PronunciationErrorType.repeatedWord =>
        'The word may have been repeated. Try once more.',
    };
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.controller,
    required this.referencePlayer,
    required this.repository,
    required this.onPracticeWord,
  });
  final LocalSettings settings;
  final RecitationController controller;
  final QuranReferencePlayer referencePlayer;
  final QuranRepository repository;
  final Future<void> Function(int surah, int ayah, int wordIndex)
  onPracticeWord;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListenableBuilder(
      listenable: settings,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          const _SettingsHeading('Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<AppAppearance>(
                    segments: const [
                      ButtonSegment(
                        value: AppAppearance.system,
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: AppAppearance.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: AppAppearance.dark,
                        label: Text('Dark'),
                      ),
                    ],
                    showSelectedIcon: false,
                    selected: {settings.appearance},
                    onSelectionChanged: (value) =>
                        settings.setAppearance(value.first),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      for (final palette in AppColorTheme.values)
                        Expanded(
                          child: _PaletteChoice(
                            palette: palette,
                            selected: settings.colorTheme == palette,
                            onTap: () => settings.setColorTheme(palette),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SettingsHeading('Reading'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Arabic text size',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        settings.arabicSize.round().toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: settings.arabicSize,
                    min: 28,
                    max: 56,
                    divisions: 14,
                    onChanged: settings.setArabicSize,
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      'الرَّحْمَٰنِ',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: quranIndoPakFontFamily,
                        fontSize: settings.arabicSize,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SettingsHeading('About & privacy'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.hearing_rounded),
              title: Text('Tajwīd feedback · limited'),
              subtitle: Text(
                'Listen mode can suggest practice when a doubled consonant sounds single. '
                'Joined sounds are assessed as a phrase. Follow mode does not grade.\n\n'
                'Madd length, ghunnah, ikhfā’, qalqalah and other tajwīd rules are not graded. '
                'A matching model symbol does not prove a rule was performed correctly.',
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                teacherDisclaimer,
                style: const TextStyle(fontSize: 17, height: 1.45),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('App information'),
              subtitle: const Text('Model, recitation and local privacy'),
              shape: const Border(),
              collapsedShape: const Border(),
              children: const [
                ListTile(
                  leading: Icon(Icons.memory_rounded),
                  title: Text('Model information'),
                  subtitle: Text(
                    'Speech recognition powered by Quran-Lab Zipformer\nv3.1 · Hafs ’an ’Asim\nQuran-Lab No-Profit License 1.2\nConservative phoneme findings and supported shaddah practice are active. Unvalidated tajwīd rules remain disabled.',
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.headphones_rounded),
                  title: Text('Reference recitation'),
                  subtitle: Text(
                    'AbdulBaset AbdulSamad · Mujawwad\nAl-Fātiḥah is bundled. Other surahs download to this phone when played or when you tap their download button.',
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.account_tree_outlined),
                  title: Text('Pronunciation mapping'),
                  subtitle: SelectableText(
                    'All 6,236 verses · joined sounds reviewed as phrases.\nSource: quran-transcript (MIT), github.com/obadx/quran-transcript\nQuran text provenance: Tanzil Project (CC BY 3.0), https://tanzil.net\nMapping coverage does not guarantee recognition accuracy or full tajwīd grading.',
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.lock_outline_rounded),
                  title: Text('Local privacy'),
                  subtitle: Text(
                    'Normal microphone audio is not saved. Accuracy-check audio is stored only after you explicitly tap Save. Settings, attempts, and saved samples stay on this phone.',
                  ),
                ),
              ],
            ),
          ),
          if (controller.progress != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insights_outlined),
              title: const Text('Practice progress'),
              subtitle: const Text(
                'Attempts and words that may need more practice.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ProgressScreen(
                    progress: controller.progress!,
                    repository: repository,
                    onPracticeWord: onPracticeWord,
                  ),
                ),
              ),
            ),
          if (controller.calibration != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Accuracy check'),
              subtitle: const Text(
                'Save known examples locally before changing recognition thresholds.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/calibration'),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.monitor_heart_outlined),
            title: const Text('Developer diagnostics'),
            subtitle: const Text(
              'View microphone input and raw Quran-Lab phoneme output.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/debug'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete all local data?'),
                  content: const Text(
                    'Resets settings, deletes downloaded recitation audio, the offline AI assistant model and practice history, and clears the current microphone session.',
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
              if (confirmed != true) return;
              await controller.stopMicrophone();
              controller.clearSession();
              await controller.progress?.deleteAll();
              await controller.calibration?.deleteAll();
              await referencePlayer.deleteDownloads();
              try {
                await LocalQwenEngine().deleteModel();
              } on MissingPluginException {
                // The assistant is iOS-only; older builds do not have this channel.
              }
              await settings.deleteAll();
              if (context.mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
            child: const Text('Delete all local data'),
          ),
        ],
      ),
    ),
  );
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
    child: Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _PaletteChoice extends StatelessWidget {
  const _PaletteChoice({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppColorTheme palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${palette.label} color scheme',
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? palette.seed.withValues(alpha: .14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: palette.seed,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                        width: 2.5,
                      )
                    : null,
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    )
                  : null,
            ),
            const SizedBox(height: 5),
            Text(
              palette.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({
    super.key,
    required this.progress,
    required this.repository,
    required this.onPracticeWord,
  });

  final LocalProgressRepository progress;
  final QuranRepository repository;
  final Future<void> Function(int surah, int ayah, int wordIndex)
  onPracticeWord;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Practice progress')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: progress,
        builder: (context, _) {
          final records = progress.records;
          final weakWords = progress.weakWordSummaries;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ProgressCount(
                      label: 'Attempts',
                      value: progress.totalAttempts,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ProgressCount(
                      label: 'Strong matches',
                      value: progress.acceptedAttempts,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ProgressCount(
                      label: 'Review',
                      value: progress.reviewAttempts,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Words to revisit',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (weakWords.isEmpty)
                const Text('No repeated review suggestions yet.')
              else
                for (final summary in weakWords)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      summary.word,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: quranIndoPakFontFamily,
                        fontSize: 28,
                        height: 1.8,
                      ),
                    ),
                    subtitle: Text(
                      '${repository.getChapter(summary.surah).name} ${summary.ayah} · ${summary.reviewCount} review ${summary.reviewCount == 1 ? "attempt" : "attempts"}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onPracticeWord(
                      summary.surah,
                      summary.ayah,
                      summary.wordIndex,
                    ),
                  ),
              const SizedBox(height: 24),
              Text(
                'Recent attempts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Word-practice attempts will appear here. Audio is never stored.',
                  ),
                )
              else
                for (final record in records.take(20))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      record.word,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: quranIndoPakFontFamily,
                        fontSize: 28,
                        height: 1.8,
                      ),
                    ),
                    subtitle: Text(
                      '${_progressStatus(record.status)} · ${_date(record.practicedAt)}',
                    ),
                    trailing: record.meanConfidence == null
                        ? const Icon(Icons.chevron_right)
                        : Text(
                            '${(record.meanConfidence! * 100).toStringAsFixed(0)}%',
                          ),
                    onTap: () => onPracticeWord(
                      record.surah,
                      record.ayah,
                      record.wordIndex,
                    ),
                  ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: records.isEmpty ? null : progress.deleteAll,
                child: const Text('Delete practice history'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Only attempt metadata is stored locally. Microphone audio is not saved.',
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    ),
  );

  static String _progressStatus(WordFeedbackStatus status) => switch (status) {
    WordFeedbackStatus.accepted => 'Strong phoneme match',
    WordFeedbackStatus.needsReview => 'Needs review',
    WordFeedbackStatus.current => 'Incomplete',
    WordFeedbackStatus.unread || WordFeedbackStatus.uncertain => 'Uncertain',
  };

  static String _date(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}

class _ProgressCount extends StatelessWidget {
  const _ProgressCount({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Column(
        children: [
          Text('$value', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
