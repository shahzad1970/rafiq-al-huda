import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dua/dua_catalog.dart';
import '../../core/quran/quran_repository.dart';
import '../../core/settings/local_settings.dart';

const _categoryIcons = <String, IconData>{
  'goodness': Icons.wb_sunny_outlined,
  'guidance': Icons.auto_stories_outlined,
  'forgiveness': Icons.favorite_border_rounded,
  'family': Icons.people_outline_rounded,
  'strength': Icons.spa_outlined,
  'acceptance': Icons.volunteer_activism_outlined,
  'morning': Icons.wb_twilight_rounded,
  'evening': Icons.nights_stay_outlined,
  'sleep': Icons.bedtime_outlined,
  'home': Icons.home_outlined,
  'food': Icons.restaurant_outlined,
  'prayer': Icons.mosque_outlined,
  'travel': Icons.flight_outlined,
  'weather': Icons.water_drop_outlined,
  'protection': Icons.shield_outlined,
};
const _categoryColors = <String, Color>{
  'goodness': Color(0xff9a6b1c),
  'guidance': Color(0xff386ba0),
  'forgiveness': Color(0xff9d526c),
  'family': Color(0xff8063a4),
  'strength': Color(0xff347a68),
  'acceptance': Color(0xff9a6543),
};

class DuaScreen extends StatefulWidget {
  const DuaScreen({
    super.key,
    required this.repository,
    required this.settings,
  });
  final QuranRepository repository;
  final LocalSettings settings;
  @override
  State<DuaScreen> createState() => _DuaScreenState();
}

class _DuaScreenState extends State<DuaScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String? _category;
  bool _saved = false;
  bool _all = false;
  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _selectCategory(String? id) {
    setState(() => _category = id);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _open(DuaEntry dua) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => DuaDetailScreen(
        dua: dua,
        repository: widget.repository,
        settings: widget.settings,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      final browsing =
          !_saved && !_all && _category == null && _search.text.trim().isEmpty;
      final results = DuaCatalog.search(
        widget.repository,
        _search.text,
        category: _category,
        favourites: _saved ? widget.settings.favouriteDuas : null,
      );
      final category = _category == null
          ? null
          : DuaCatalog.categories.firstWhere((c) => c.id == _category);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Duʿā'),
          leading: IconButton(
            tooltip: 'Return to dashboard',
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 40),
            children: [
              Text(
                'A duʿā for\nevery moment.',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${DuaCatalog.entries.length} duʿās & adhkār · Read offline',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search a need or a duʿā',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_search.clear),
                        ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(
                    alpha: .55,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(
                    value: false,
                    icon: Icon(Icons.grid_view_rounded),
                    label: Text('Browse'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.bookmark_border_rounded),
                    label: Text(
                      'Saved (${widget.settings.favouriteDuas.length})',
                    ),
                  ),
                ],
                selected: {_saved},
                onSelectionChanged: (value) => setState(() {
                  _saved = value.single;
                  _category = null;
                  _all = false;
                }),
              ),
              const SizedBox(height: 26),
              if (browsing) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _all = true),
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('View all duʿās'),
                  ),
                ),
                Text(
                  'Browse by need',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, box) {
                    final columns =
                        MediaQuery.textScalerOf(context).scale(16) > 22 ? 1 : 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final item in DuaCatalog.categories)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: 160,
                              minWidth:
                                  (box.maxWidth - 12 * (columns - 1)) / columns,
                              maxWidth:
                                  (box.maxWidth - 12 * (columns - 1)) / columns,
                            ),
                            child: Material(
                              color: scheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                key: ValueKey('dua-category-${item.id}'),
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _selectCategory(item.id),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                            (_categoryColors[item.id] ??
                                                    scheme.primary)
                                                .withValues(alpha: .12),
                                        child: Icon(
                                          _categoryIcons[item.id],
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? scheme.primary
                                              : _categoryColors[item.id],
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(height: 13),
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${DuaCatalog.entries.where((d) => d.inCategory(item.id)).length} entries',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 26),
                Text(
                  'Start with a short duʿā',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _tile(
                  DuaCatalog.entries.firstWhere((d) => d.id == 'knowledge'),
                ),
              ] else ...[
                if (_all)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _all = false),
                      icon: const Icon(Icons.grid_view_rounded),
                      label: const Text('Browse categories'),
                    ),
                  ),
                if (category != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'All categories',
                        icon: const Icon(Icons.close),
                        onPressed: () => _selectCategory(null),
                      ),
                    ],
                  ),
                  Text(
                    category.subtitle,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                ] else
                  Text(
                    _saved ? 'Your saved duʿās' : '${results.length} results',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                const SizedBox(height: 12),
                if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          _saved
                              ? Icons.bookmark_border_rounded
                              : Icons.search_off_rounded,
                          size: 40,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _saved && _search.text.isEmpty
                              ? 'Keep your favourites close'
                              : 'No matching duʿās',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _saved && _search.text.isEmpty
                              ? 'Tap a bookmark beside any duʿā to save it here.'
                              : 'Try a word like parents, knowledge or mercy.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                for (final dua in results)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _tile(dua),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Widget _tile(DuaEntry dua) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      key: ValueKey('dua-${dua.id}'),
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      title: Text(
        dua.title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          dua.isQuranExcerpt ? dua.reference : 'Duʿā & dhikr collection',
          maxLines: 2,
        ),
      ),
      trailing: IconButton(
        tooltip: widget.settings.favouriteDuas.contains(dua.id)
            ? 'Unsave ${dua.title}'
            : 'Save ${dua.title}',
        icon: Icon(
          widget.settings.favouriteDuas.contains(dua.id)
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
        ),
        onPressed: () => widget.settings.toggleDuaFavourite(dua.id),
      ),
      onTap: () => _open(dua),
    ),
  );
}

class DuaDetailScreen extends StatelessWidget {
  const DuaDetailScreen({
    super.key,
    required this.dua,
    required this.repository,
    required this.settings,
  });
  final DuaEntry dua;
  final QuranRepository repository;
  final LocalSettings settings;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Duʿā'),
          actions: [
            IconButton(
              tooltip: settings.favouriteDuas.contains(dua.id)
                  ? 'Remove favourite'
                  : 'Save favourite',
              onPressed: () => settings.toggleDuaFavourite(dua.id),
              icon: Icon(
                settings.favouriteDuas.contains(dua.id)
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 48),
            children: [
              Text(
                dua.title,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.6),
              ),
              const SizedBox(height: 10),
              Text(
                dua.reference,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .065),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  dua.arabic(repository),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'QuranIndoPak',
                    fontSize: settings.arabicSize,
                    height: 2.05,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'MEANING IN ENGLISH',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                dua.meaning,
                style: const TextStyle(fontSize: 20, height: 1.55),
              ),
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                dua.isQuranExcerpt && (dua.start > 0 || dua.end != null)
                    ? 'Source · excerpt from ${dua.reference}'
                    : 'Source · ${dua.reference}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (!dua.isQuranExcerpt) ...[
                const Text(
                  'Arabic and English: Fitrahive Duʿā & Dhikr (MIT). References are reproduced from the collection; individual narrations have not been independently graded in this app.',
                ),
                const SizedBox(height: 12),
              ],
              SelectableText(
                dua.sourceUrl,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy duʿā'),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text:
                          '${dua.arabic(repository)}\n\n${dua.meaning}\n${dua.reference}',
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Duʿā copied')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
