import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ask/ask_translation.dart';
import '../../core/audio/quran_reference_player.dart';
import '../../core/prayer/prayer_courses.dart';
import '../../core/prayer/wudu_lesson.dart';
import '../../core/quran/quran_repository.dart';
import '../../core/settings/local_settings.dart';

class PrayerTeacherScreen extends StatefulWidget {
  const PrayerTeacherScreen({
    super.key,
    required this.repository,
    required this.settings,
  });
  final QuranRepository repository;
  final LocalSettings settings;
  @override
  State<PrayerTeacherScreen> createState() => _PrayerTeacherScreenState();
}

class _PrayerTeacherScreenState extends State<PrayerTeacherScreen>
    with WidgetsBindingObserver {
  late final lesson = AskTranslation.load();
  PrayerCourse selected = prayerCourses[1];
  String? selectedDay;
  bool pairMethod = false;
  bool followSequence = false;
  List<PrayerCourse> get sequence =>
      dailyPrayerSequence(selectedDay ?? 'Fajr', pairs: pairMethod);
  PrayerCourse? get nextCourse {
    if (!followSequence || wudu) return null;
    final position = sequence.indexOf(selected);
    return position >= 0 && position + 1 < sequence.length
        ? sequence[position + 1]
        : null;
  }

  void beginCourse(PrayerCourse course, {bool wholePrayer = false}) {
    setState(() {
      selected = course;
      followSequence = wholePrayer;
      wudu = false;
      index = 0;
      started = true;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> backToOverview() async {
    await player.stop();
    if (!mounted) return;
    setState(() {
      if (started) {
        started = false;
      } else {
        selectedDay = null;
      }
      index = 0;
      followSequence = false;
    });
  }

  final player = QuranReferencePlayer();
  final scroll = ScrollController();
  int index = 0;
  bool started = false;
  bool wudu = false;
  bool moving = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(player.stop());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    player.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> move(int next) async {
    if (moving) return;
    moving = true;
    await player.stop();
    if (!mounted) return;
    setState(() {
      index = next;
      moving = false;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !started && selectedDay == null,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) unawaited(player.stop());
      if (!didPop) unawaited(backToOverview());
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(wudu && started ? 'Wudu' : selectedDay ?? 'Prayer Teacher'),
        leading: started || selectedDay != null
            ? IconButton(
                tooltip: 'Back to prayers',
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: backToOverview,
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'About this lesson',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Learn with a teacher'),
                content: const SingleChildScrollView(
                  child: Text(
                    'Beginner lessons for the five daily prayers, common sunnah prayers and Witr, performed alone. It is not a complete guide to all four schools. School differences are shown where noted; consult a qualified teacher for your own practice and accessibility needs.\n\nIllustrations show example positions, not every school’s hand, finger or foot placement. School-specific details still need qualified teacher review. No camera or pronunciation grading is used here.\n\nQur’an meanings: Rowwad Translation Center / QuranEnc. Other meanings are brief editorial renderings. Qur’an audio: AbdulBaset AbdulSamad Mujawwad. Al-Fātiḥah is bundled; other recitation may require a first download. Prayer phrases: human recordings from IslamCan, Hisn al-Muslim (via Barakah Life), The Islamic Bulletin and Islam im Herzen. Bundled for this personal-use app; redistribution permissions require review. Some teaching clips repeat the phrase. Missing phrase recordings use a labelled on-device Arabic generated voice, which can mispronounce words and is not a tajwīd model. Audio and illustrations should be reviewed with a qualified teacher.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<AskTranslation>(
        future: lesson,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('The lesson could not load. Please reopen it.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final steps = wudu
              ? wuduLesson
              : prayerCourseLesson(selected, widget.repository, snapshot.data!);
          if (!started) {
            if (selectedDay == null) {
              return ListView(
                key: const ValueKey('daily-prayer-list'),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Choose a prayer',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  for (final day in dailyPrayerNames)
                    Card(
                      child: ListTile(
                        key: ValueKey('prayer-$day'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        title: Text(day, style: const TextStyle(fontSize: 22)),
                        subtitle: Text(
                          dailyPrayerSequence(day)
                              .map((c) => c.label)
                              .join(' → '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => setState(() {
                          selectedDay = day;
                          pairMethod = false;
                          wudu = false;
                        }),
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      wudu = true;
                      index = 0;
                      started = true;
                      followSequence = false;
                    }),
                    icon: const Icon(Icons.water_drop_outlined),
                    label: const Text('Learn wudu'),
                  ),
                ],
              );
            }
            return ListView(
              key: ValueKey('overview-$selectedDay'),
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Full prayer guide',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text('Fard = obligatory · Sunnah = recommended'),
                if (selectedDay == 'Dhuhr' || selectedDay == 'Isha') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<bool>(
                    initialValue: pairMethod,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: selectedDay == 'Isha'
                          ? 'Witr method'
                          : 'Sunnah before Dhuhr',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: false,
                        child: Text(
                          selectedDay == 'Isha'
                              ? '3 together · Hanafi (wajib)'
                              : '4 together · Hanafi',
                        ),
                      ),
                      DropdownMenuItem(
                        value: true,
                        child: Text(
                          selectedDay == 'Isha'
                              ? '2 + 1 · Sunnah method'
                              : '2 + 2',
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => pairMethod = value);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                for (var n = 0; n < sequence.length; n++)
                  Card(
                    child: ListTile(
                      key: ValueKey('prayer-part-$n'),
                      leading: CircleAvatar(child: Text('${n + 1}')),
                      title: Text(sequence[n].label),
                      subtitle: Text(
                        sequence[n].fard
                            ? 'Obligatory'
                            : sequence[n].hanafiWitr
                            ? 'Wajib · Hanafi'
                            : sequence[n].label.contains('optional')
                            ? 'Optional'
                            : 'Sunnah',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => beginCourse(sequence[n]),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('start-full-prayer'),
                  onPressed: () =>
                      beginCourse(sequence.first, wholePrayer: true),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start full prayer'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Learn every part in order, or tap a part to practise it.',
                ),
              ],
            );
          }
          final step = steps[index];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    LinearProgressIndicator(value: (index + 1) / steps.length),
                    const SizedBox(height: 8),
                    if (!wudu)
                      Text(
                        selected.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    Text(
                      '${wudu
                          ? 'Wudu'
                          : step.rakah == 0
                          ? 'Preparation'
                          : 'Rakʿah ${step.rakah} of ${selected.rakahs}'} · ${index + 1} / ${steps.length}',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      step.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      label: wudu
                          ? '${step.title} illustration'
                          : '${step.illustration} prayer posture illustration',
                      image: true,
                      child: SizedBox(
                        height: 250,
                        width: double.infinity,
                        child: Image.asset(
                          step.illustrationAsset,
                          fit: BoxFit.contain,
                          cacheHeight: 750,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.instruction,
                      style: const TextStyle(fontSize: 19, height: 1.5),
                    ),
                    if (step.arabic.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      SelectableText(
                        step.arabic,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'QuranIndoPak',
                          fontSize: widget.settings.arabicSize,
                          height: 1.9,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SelectableText(
                        step.meaning,
                        style: const TextStyle(fontSize: 20, height: 1.5),
                      ),
                    ],
                    if (step.arabic.isNotEmpty)
                      ListenableBuilder(
                        listenable: player,
                        builder: (context, _) => Column(
                          children: [
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: player.loading
                                  ? null
                                  : () => player.playing
                                        ? player.stop()
                                        : step.audio != null
                                        ? player.playVerse(step.audio!)
                                        : player.speakArabic(step.arabic),
                              icon: Icon(
                                player.playing
                                    ? Icons.stop
                                    : Icons.volume_up_outlined,
                              ),
                              label: Text(
                                player.loading
                                    ? 'Loading…'
                                    : player.playing
                                    ? 'Stop audio'
                                    : step.audio == null
                                    ? 'Listen · generated voice'
                                    : 'Listen',
                              ),
                            ),
                            if (player.error != null) Text(player.error!),
                          ],
                        ),
                      ),
                    if (step.differences.isNotEmpty)
                      ExpansionTile(
                        key: ValueKey('differences-$index'),
                        title: const Text('School differences'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              step.differences,
                              style: const TextStyle(fontSize: 18, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous step',
                        onPressed: index == 0 || moving
                            ? null
                            : () => move(index - 1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: moving
                            ? null
                            : () async {
                                if (index < steps.length - 1) {
                                  await move(index + 1);
                                } else {
                                  final upcoming = nextCourse;
                                  await move(0);
                                  if (!mounted) return;
                                  if (upcoming != null) {
                                    beginCourse(upcoming, wholePrayer: true);
                                  } else {
                                    setState(() => started = false);
                                  }
                                }
                              },
                        icon: Icon(
                          index == steps.length - 1
                              ? Icons.check
                              : Icons.chevron_right,
                        ),
                        label: Text(
                          index == steps.length - 1
                              ? nextCourse != null
                                    ? 'Next prayer part'
                                    : 'Finish lesson'
                              : 'Next step',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
