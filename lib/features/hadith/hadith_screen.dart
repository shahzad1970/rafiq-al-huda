import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/hadith/hadith_repository.dart';
import '../../core/settings/local_settings.dart';
import '../../core/ask/ask_library.dart';
import '../../core/ask/hadith_questions.dart';
import '../ask/ask_screen.dart';
import '../../core/text/arabic_span.dart';
export '../../core/text/arabic_span.dart' show hadithArabicSpan;

class HadithScreen extends StatefulWidget {
  const HadithScreen({super.key, required this.settings, this.repository});
  final LocalSettings settings;
  final HadithRepository? repository;
  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  late final repository = widget.repository ?? HadithRepository();
  late Future<List<HadithCollection>> future = repository.collections();
  String query = '';
  @override
  void dispose() {
    repository.clearCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Hadith'),
      leading: IconButton(
        tooltip: 'Return to dashboard',
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: SafeArea(
      child: FutureBuilder<List<HadithCollection>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LoadError(
              onRetry: () => setState(() => future = repository.collections()),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final collections = all
              .where(
                (c) =>
                    normalizeHadith(c.title)
                        .contains(normalizeHadith(query.trim())),
              )
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The Hadith library',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${all.length} collections · ${all.fold<int>(0, (n, c) => n + c.count)} entries · Offline',
                    ),
                    const SizedBox(height: 16),
                    _Search(
                      hint: 'Find a collection',
                      onChanged: (v) => setState(() => query = v),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
                  itemCount: collections.length + 1,
                  itemBuilder: (context, index) {
                    if (index == collections.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'All 10 collections available in this source edition—not every hadith work. Text, numbering and reported grades follow the source; coverage varies by edition.',
                        ),
                      );
                    }
                    final c = collections[index];
                    return Card(
                      child: ListTile(
                        key: ValueKey('hadith-${c.id}'),
                        contentPadding: const EdgeInsets.all(16),
                        leading: Icon(
                          Icons.auto_stories_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          c.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          '${c.books.length} books · ${c.count} entries${c.unavailableCount == 0 ? '' : '\n${c.unavailableCount} source entries have no text'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => _BooksScreen(
                              collection: c,
                              repository: repository,
                              settings: widget.settings,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _BooksScreen extends StatefulWidget {
  const _BooksScreen({
    required this.collection,
    required this.repository,
    required this.settings,
  });
  final HadithCollection collection;
  final HadithRepository repository;
  final LocalSettings settings;
  @override
  State<_BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<_BooksScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final books = widget.collection.search(query);
    return Scaffold(
      appBar: AppBar(title: Text(widget.collection.title)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: _Search(
                hint: 'Find a book or hadith number',
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            if (books.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No matching book or source-edition number.'),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: books.length,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemBuilder: (context, index) {
                  final book = books[index];
                  return Card(
                    child: ListTile(
                      key: ValueKey('hadith-book-${book.id}'),
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(book.title),
                      subtitle: Text('Book ${book.id} · ${book.count} entries'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => _BookScreen(
                            collection: widget.collection,
                            book: book,
                            repository: widget.repository,
                            settings: widget.settings,
                            initialQuery: book.numbers.contains(query.trim())
                                ? query.trim()
                                : '',
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookScreen extends StatefulWidget {
  const _BookScreen({
    required this.collection,
    required this.book,
    required this.repository,
    required this.settings,
    this.initialQuery = '',
  });
  final HadithCollection collection;
  final HadithBook book;
  final HadithRepository repository;
  final LocalSettings settings;
  final String initialQuery;
  @override
  State<_BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<_BookScreen> {
  late String query = widget.initialQuery;
  late Future<List<HadithRecord>> future = widget.repository.loadBook(
    widget.book,
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.book.title)),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: _Search(
              initialValue: query,
              hint: 'Search this book · Arabic or English',
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<HadithRecord>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _LoadError(
                    onRetry: () => setState(
                      () => future = widget.repository.loadBook(widget.book),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final records = snapshot.data!;
                final matches = records.where((h) => h.matches(query)).toList();
                if (matches.isEmpty) {
                  return const Center(
                    child: Text('No matching narrations in this book.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final h = matches[index];
                    return Card(
                      child: ListTile(
                        key: ValueKey(h.id),
                        contentPadding: const EdgeInsets.all(18),
                        title: Text(
                          'Hadith ${h.number}${h.usesAiTranslation ? ' · AI translation' : ''}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            h.displayEnglish ??
                                h.arabic ??
                                'Text unavailable in this edition.',
                            textDirection: h.displayEnglish == null
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17, height: 1.45),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => HadithReaderScreen(
                              collection: widget.collection,
                              book: widget.book,
                              records: records,
                              index: records.indexOf(h),
                              settings: widget.settings,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class HadithReaderScreen extends StatefulWidget {
  const HadithReaderScreen({
    super.key,
    required this.collection,
    required this.book,
    required this.records,
    required this.index,
    required this.settings,
  });
  final HadithCollection collection;
  final HadithBook book;
  final List<HadithRecord> records;
  final int index;
  final LocalSettings settings;
  @override
  State<HadithReaderScreen> createState() => _HadithReaderScreenState();
}

class _HadithReaderScreenState extends State<HadithReaderScreen> {
  late int index = widget.index;
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void move(int step) {
    setState(() => index += step);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.records[index];
    final source =
        'https://github.com/fawazahmed0/hadith-api/blob/${HadithRepository.revision}/editions/${widget.collection.englishEdition}.json';
    return Scaffold(
      appBar: AppBar(
        title: Text('Hadith ${h.number}'),
        actions: [
          IconButton(
            tooltip: 'Source details',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Source details'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Source: Hadith API by Fawaz Ahmed. ${h.usesAiTranslation ? 'Arabic and numbering follow the source; the English is AI-generated by OpenAI, not the source publisher’s translation.' : 'Numbering and translation follow this edition.'} This app does not independently authenticate narrations or issue rulings.',
                      ),
                      const SizedBox(height: 12),
                      SelectableText(source),
                      if (h.arabic != null) ...[
                        const SizedBox(height: 12),
                        SelectableText(
                          source.replaceFirst(
                            widget.collection.englishEdition,
                            widget.collection.arabicEdition,
                          ),
                        ),
                      ],
                    ],
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
          IconButton(
            tooltip: 'Copy hadith',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text:
                      '${widget.collection.title} · Hadith ${h.number}\n\n${h.arabic ?? ''}\n\n${h.englishForCopy}\n\n${h.usesAiTranslation ? source.replaceFirst(widget.collection.englishEdition, widget.collection.arabicEdition) : source}',
                ),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Hadith copied')));
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Previous hadith',
                onPressed: index > 0 ? () => move(-1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${index + 1} of ${widget.records.length}'),
              IconButton(
                tooltip: 'Next hadith',
                onPressed: index + 1 < widget.records.length
                    ? () => move(1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            Text(
              widget.collection.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.book.title == widget.collection.title ? '' : '${widget.book.title}\n'}Book ${h.book}, narration ${h.bookNumber}',
            ),
            const SizedBox(height: 28),
            if (h.arabic != null)
              SelectableText.rich(
                hadithArabicSpan(h.arabic!),
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'QuranIndoPak',
                  fontSize: widget.settings.arabicSize,
                  height: 1.9,
                ),
              )
            else
              const Text(
                'Arabic text is not available for this entry in the selected edition.',
              ),
            const SizedBox(height: 28),
            Text(
              'ENGLISH',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (h.usesAiTranslation) ...[
              Container(
                key: const ValueKey('ai-translation-notice'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '${HadithRecord.aiTranslationLabel}\nGenerated from the Arabic because the source has no English. It may contain errors; consult a qualified scholar for interpretation.',
                ),
              ),
              const SizedBox(height: 16),
            ],
            SelectableText(
              h.displayEnglish ?? 'English translation is not available for this entry in the selected edition.',
              style: const TextStyle(fontSize: 20, height: 1.6),
            ),
            if (h.usesAiTranslation && h.aiTranslationNote != null) ...[
              const SizedBox(height: 16),
              Text(
                'Translation note: ${h.aiTranslationNote}',
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
            const SizedBox(height: 28),
            if (h.english != null)
              Card(
                key: ValueKey('hadith-ask-${h.id}'),
                child: ExpansionTile(
                  title: const Text('Ask AI about this hadith'),
                  leading: const Icon(Icons.question_answer_outlined),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    AskScreen(
                      inline: true,
                      selected: AskSource.hadith(h, widget.collection.title),
                      suggestedQuestions: hadithQuestions(h.english!),
                    ),
                  ],
                ),
              )
            else
              const Text(
                'Ask AI needs a published English translation for this hadith.',
              ),
          ],
        ),
      ),
    );
  }
}

/// Preserve source punctuation with a system face outside the Quran font's range.
class _Search extends StatelessWidget {
  const _Search({
    required this.hint,
    required this.onChanged,
    this.initialValue = '',
  });
  final String hint, initialValue;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: initialValue,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search),
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Could not open the local library.'),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
