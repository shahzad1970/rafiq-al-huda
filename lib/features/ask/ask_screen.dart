import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ask/ask_engine.dart';
import '../../core/ask/ask_library.dart';
import '../../core/ask/quran_questions.dart';
import '../../core/quran/quran_repository.dart';
import '../../core/text/arabic_span.dart';

class AskScreen extends StatefulWidget {
  const AskScreen({
    super.key,
    this.repository,
    this.selected,
    this.engine,
    this.inline = false,
    this.beforeAsk,
    this.suggestedQuestions,
  }) : assert(repository != null || selected != null);
  final QuranRepository? repository;
  final AskSource? selected;
  final AskEngine? engine;
  final bool inline;
  final Future<void> Function()? beforeAsk;
  final List<String>? suggestedQuestions;
  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> with WidgetsBindingObserver {
  late final engine = widget.engine ?? LocalQwenEngine();
  late final library = AskLibrary(widget.repository);
  final input = TextEditingController();
  final answerAnchor = GlobalKey();
  StreamSubscription<Map<String, dynamic>>? subscription;
  bool ready = false, checking = true, busy = false;
  int generation = 0;
  double? progress;
  String status = '', question = '';
  String scope = 'all';
  Duration? answerTime;
  List<AskSource> sources = [];
  AskAnswer? answer;
  List<String>? verseQuestions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    subscription = engine.events.listen((event) {
      if (!mounted || !busy) return;
      setState(() {
        progress = (event['progress'] as num?)?.toDouble();
        status = switch (event['state']) {
          'downloading' =>
            progress == 1 ? 'Verifying model…' : 'Downloading model…',
          'loading' => 'Verifying and loading model…',
          'generating' => 'Preparing an explanation on your iPhone…',
          'cancelled' => 'Stopping…',
          _ => status,
        };
      });
    }, onError: (_) {});
    _check();
    _loadVerseQuestions();
  }

  Future<void> _loadVerseQuestions() async {
    final selected = widget.selected;
    if (widget.suggestedQuestions != null ||
        selected == null ||
        !selected.id.startsWith('quran:')) {
      return;
    }
    verseQuestions = quranQuestions('');
    try {
      final enriched = await library.enrich(selected);
      if (!mounted) return;
      setState(() => verseQuestions = quranQuestions(enriched.english));
    } catch (_) {
      // Keep neutral starters if published translation loading fails.
      // The answer path separately reports unavailable source evidence.
    }
  }

  Future<void> _check() async {
    try {
      final value = await engine.installed();
      if (mounted) {
        setState(() {
          ready = value;
          checking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          checking = false;
          status = 'The offline assistant requires the updated iPhone app.';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && busy) _stop();
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(engine.cancel().catchError((_) {}));
    unawaited(subscription?.cancel());
    input.dispose();
    super.dispose();
  }

  Future<void> _stop() async {
    generation++;
    try {
      await engine.cancel();
    } catch (_) {}
    if (mounted) {
      setState(() {
        busy = false;
        status = 'Stopped. You can ask again.';
        progress = null;
      });
    }
  }

  Future<void> _download() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download offline AI?'),
        content: const Text(
          'Downloads 2.74 GB from Hugging Face. Wi-Fi is recommended; allow at least 3.4 GB free storage. After download, questions and answers stay on your phone. Downloads stop when you leave this screen.\n\nQwen3.5-4B · Apache 2.0. AI can make mistakes and does not replace a qualified scholar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final token = ++generation;
    setState(() {
      busy = true;
      progress = 0;
      status = 'Starting download…';
    });
    try {
      await engine.download();
      if (mounted && generation == token) {
        setState(() {
          ready = true;
          status = 'Offline model installed.';
        });
      }
    } catch (error) {
      _error(error, token);
    } finally {
      if (mounted && generation == token) {
        setState(() {
          busy = false;
          progress = null;
        });
      }
    }
  }

  Future<void> _ask() async {
    final text = input.text.trim();
    if (text.isEmpty || busy || !ready) return;
    FocusScope.of(context).unfocus();
    final token = ++generation;
    setState(() {
      busy = true;
      status = 'Searching the offline library…';
      answerTime = null;
      question = text;
      answer = null;
      sources = [];
    });
    final timer = Stopwatch()..start();
    try {
      await widget.beforeAsk?.call();
      if (!mounted || generation != token) return;
      final found = await library.search(
        text,
        selected: widget.selected,
        scope: scope,
      );
      if (!mounted || generation != token) return;
      setState(() {
        sources = found;
      });
      if (found.isEmpty) {
        setState(() {
          status = 'No matching passages found. Try a specific topic or a reference such as 2:255.';
        });
        return;
      }
      final raw = await engine.answer(askPrompt(text, found));
      if (!mounted || generation != token) return;
      final parsed = AskAnswer.parse(raw, found.length);
      setState(() {
        answer = parsed;
        answerTime = timer.elapsed;
        status = parsed.claims.isEmpty
            ? 'The retrieved passages do not provide enough support for an answer. Try narrowing your question.'
            : '';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != token) return;
        final target = answerAnchor.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    } catch (error) {
      _error(error, token);
    } finally {
      if (mounted && generation == token) {
        setState(() {
          busy = false;
          progress = null;
        });
      }
    }
  }

  void _error(Object error, int token) {
    if (!mounted || generation != token) return;
    setState(() {
      status = error is AskCitationException
          ? 'The answer contained missing or invalid source references. Please retry. You can still read the sources below.'
          : error is FormatException
          ? 'The AI response was incomplete or incorrectly formatted. Please retry. You can still read the sources below.'
          : error is PlatformException
          ? error.message ?? 'The offline model could not answer. Please retry.'
          : 'Unable to complete this request. Please retry.';
    });
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete offline AI model?'),
        content: const Text(
          'Frees approximately 2.74 GB. Your Qur’an and hadith library will remain available.',
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
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      status = 'Deleting model…';
    });
    try {
      await engine.deleteModel();
      if (mounted) {
        setState(() {
          ready = false;
          status = 'Model deleted.';
          answer = null;
          sources = [];
        });
      }
    } catch (e) {
      _error(e, generation);
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  void _source(int index) {
    final source = sources[index];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          children: [
            Text(
              source.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(source.provenance),
            const SizedBox(height: 24),
            if (source.arabic.isNotEmpty)
              SelectableText.rich(
                hadithArabicSpan(source.arabic),
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'QuranIndoPak',
                  fontSize: 30,
                  height: 1.9,
                ),
              ),
            const SizedBox(height: 24),
            Text(
              source.englishLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SelectableText(
              source.english,
              style: const TextStyle(fontSize: 19, height: 1.6),
            ),
            if (source.notes.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Publisher’s notes · not AI',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SelectableText(
                source.notes,
                style: const TextStyle(fontSize: 18, height: 1.6),
              ),
            ],
            if (source.sourceUrl.isNotEmpty) ...[
              const SizedBox(height: 24),
              SelectableText(source.sourceUrl),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.inline
      ? _content(context)
      : Scaffold(
          appBar: AppBar(
            title: const Text('Ask Qur’an & Hadith'),
            actions: [
              PopupMenuButton<String>(
                enabled: !busy,
                tooltip: 'Assistant options',
                onSelected: (value) {
                  if (value == 'delete') {
                    _remove();
                  } else if (value == 'clear') {
                    setState(() {
                      question = '';
                      input.clear();
                      answer = null;
                      sources = [];
                      status = '';
                    });
                  } else {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Offline reading assistant',
                      children: const [
                        Text(
                          'Experimental · Qwen3.5-4B (Apache 2.0), Unsloth Q4_K_M conversion; llama.cpp b11065 (MIT).\n\nQuestions are processed locally. No conversation history is saved. Download requires internet. Sources use the bundled editions; AI translations are excluded. Citation checks verify reference identity, not whether an explanation is correct. Not a fatwa service.',
                        ),
                      ],
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'clear',
                    child: Text('Clear question'),
                  ),
                  if (ready)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete AI model'),
                    ),
                  const PopupMenuItem(
                    value: 'about',
                    child: Text('About offline AI'),
                  ),
                ],
              ),
            ],
          ),
          body: _content(context),
        );

  Widget _content(BuildContext context) => SafeArea(
    top: !widget.inline,
    bottom: !widget.inline,
    child: ListView(
      shrinkWrap: widget.inline,
      physics: widget.inline ? const NeverScrollableScrollPhysics() : null,
      padding: widget.inline ? EdgeInsets.zero : const EdgeInsets.all(22),
      children: [
        if (!ready)
          Text(
            'Explore with sources',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        if (!ready) const SizedBox(height: 16),
        if (widget.selected != null && !widget.inline)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Asking about ${widget.selected!.title}'),
            ),
          ),
        if (checking)
          const LinearProgressIndicator()
        else if (!ready) ...[
          const SizedBox(height: 12),
          const Text(
            'One-time model download · 2.74 GB\nWorks offline afterwards. No account or API key.',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : _download,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download offline AI'),
          ),
        ] else ...[
          if (widget.selected == null) ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'quran', label: Text('Qur’an')),
                ButtonSegment(value: 'hadith', label: Text('Hadith')),
              ],
              selected: {scope},
              onSelectionChanged: busy
                  ? null
                  : (value) => setState(() => scope = value.single),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: input,
            enabled: !busy,
            minLines: 1,
            maxLines: 4,
            maxLength: 600,
            style: const TextStyle(fontSize: 19, height: 1.4),
            decoration: InputDecoration(
              hintText: 'Ask a question…',
              counterText: '',
              suffixIcon: Padding(
                padding: const EdgeInsets.all(6),
                child: FilledButton(
                  onPressed: busy ? null : _ask,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  child: const Text('Ask'),
                ),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
              contentPadding: const EdgeInsets.all(18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1.5,
                ),
              ),
            ),
            onSubmitted: (_) => _ask(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final suggestion
                  in widget.suggestedQuestions ??
                      verseQuestions ??
                      (widget.selected != null
                          ? [
                              'What does this passage mean?',
                              'What can I learn from this passage?',
                            ]
                          : scope == 'hadith'
                          ? [
                              'What do hadith say about intentions?',
                              'What do hadith say about kindness?',
                            ]
                          : [
                              'What does 2:255 say about Allah?',
                              'What does the Qur’an say about patience?',
                              'What does the Qur’an say about gratitude?',
                            ]))
                ActionChip(
                  label: Text(suggestion),
                  onPressed: busy
                      ? null
                      : () {
                          input.text = suggestion;
                          _ask();
                        },
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'AI can be wrong. Check the sources.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        if (busy) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progress),
          if (progress != null) Text('${(progress! * 100).round()}%'),
          TextButton.icon(
            onPressed: _stop,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop'),
          ),
        ],
        if (status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              status,
              style: const TextStyle(fontSize: 17, height: 1.5),
            ),
          ),
        if (answer != null && answer!.claims.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            question,
            key: answerAnchor,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (final claim in answer!.claims)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    claim.text,
                    style: const TextStyle(fontSize: 19, height: 1.6),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final i in claim.citations)
                        ActionChip(
                          label: Text('Source $i'),
                          onPressed: () => _source(i - 1),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
        if (sources.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Sources', style: Theme.of(context).textTheme.titleLarge),
          const Text('Search matches · check relevance'),
          for (var i = 0; i < sources.length; i++)
            Card(
              child: ListTile(
                title: Text('${i + 1}. ${sources[i].title}'),
                subtitle: Text(
                  sources[i].english,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _source(i),
              ),
            ),
        ],
        const SizedBox(height: 40),
      ],
    ),
  );
}
