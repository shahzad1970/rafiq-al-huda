import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/prayer/mawaqit_calculator.dart';
import '../../core/prayer/prayer_schedule.dart';
import '../../core/settings/local_settings.dart';
import 'qibla_screen.dart';

const prayerLocationChannel = MethodChannel('org.quranteacher/prayer-location');

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key, required this.settings, this.now});
  final LocalSettings settings;
  final DateTime Function()? now;
  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen>
    with WidgetsBindingObserver {
  Timer? timer;
  int dayOffset = 0;
  DateTime get now => widget.now?.call() ?? DateTime.now();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      setState(() {});
    } else {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _settings() async {
    final result = await Navigator.push<PrayerConfiguration>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PrayerSetup(initial: widget.settings.prayerConfiguration),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await widget.settings.setPrayerConfiguration(result);
      if (mounted) setState(() => dayOffset = 0);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save prayer settings. Please retry.'),
          ),
        );
      }
    }
  }

  String _clock(DateTime? time) => time == null
      ? '—'
      : MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay.fromDateTime(time),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        );
  void _information() {
    final config = widget.settings.prayerConfiguration;
    showAboutDialog(
      context: context,
      applicationName: 'Prayer times',
      children: [
        if (config != null)
          Text(
            '${PrayerMethod.byCode(config.method).name}\n${config.hanafi ? 'Hanafi Asr' : 'Standard Asr'}\n${config.location.zone}\n',
          ),
        const Text(
          'Calculated start times, not mosque iqāmah times. Confirm your method with your local mosque. Sunrise is not a prayer.\n\nOffline adaptation of MAWAQIT/prayer-times and PrayTimes.org (LGPL v3), with date and polar safeguards. Sea-level calculations; no adhan notifications.\n\nhttps://github.com/mawaqit/prayer-times\nhttps://praytimes.org',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.settings.prayerConfiguration;
    final schedule = config == null ? null : PrayerSchedule(config);
    final local = schedule?.localNow(now);
    final day = local == null
        ? null
        : DateTime(local.year, local.month, local.day + dayOffset);
    final events = day == null ? <PrayerEvent>[] : schedule!.forDate(day);
    final next = schedule?.next(now);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Times'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => QiblaScreen(location: config?.location),
              ),
            ),
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Qibla'),
          ),
          IconButton(
            onPressed: _settings,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Prayer settings',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (config == null) ...[
              const SizedBox(height: 40),
              Icon(Icons.mosque_outlined, size: 72, color: colors.primary),
              const SizedBox(height: 24),
              Text(
                'Make time for prayer',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose your location to begin.',
                style: TextStyle(fontSize: 18, height: 1.5),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _settings,
                icon: const Icon(Icons.place_outlined),
                label: const Text('Set up prayer times'),
              ),
            ] else ...[
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      config.location.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _information,
                    icon: const Icon(Icons.info_outline_rounded, size: 20),
                    tooltip: 'Calculation information',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (next != null)
                Card(
                  color: colors.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UP NEXT',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: colors.onPrimary.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          next.name,
                          style: TextStyle(
                            fontSize: 22,
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _clock(next.time),
                          style: TextStyle(
                            fontSize: 42,
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _remaining(next.time!.difference(now)),
                          style: TextStyle(
                            fontSize: 17,
                            color: colors.onPrimary.withValues(alpha: 0.85),
                          ),
                        ),
                        if (next.estimated)
                          Text(
                            'High-latitude estimate',
                            style: TextStyle(color: colors.onPrimary),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    onPressed: dayOffset > -365
                        ? () => setState(() => dayOffset--)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous day',
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => dayOffset = 0),
                      child: Text(
                        '${dayOffset == 0 ? 'Today · ' : ''}${MaterialLocalizations.of(context).formatMediumDate(day!)}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: dayOffset < 365
                        ? () => setState(() => dayOffset++)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next day',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final event in events)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 2,
                        ),
                        selected:
                            dayOffset == 0 &&
                            next?.name == event.name &&
                            next?.time == event.time,
                        selectedTileColor: colors.primaryContainer.withValues(
                          alpha: 0.45,
                        ),
                        leading: Icon(
                          event.name == 'Sunrise'
                              ? Icons.wb_sunny_outlined
                              : event.name == 'Isha'
                              ? Icons.nightlight_outlined
                              : event.name == 'Fajr'
                              ? Icons.wb_twilight_rounded
                              : event.name == 'Dhuhr'
                              ? Icons.light_mode_outlined
                              : event.name == 'Asr'
                              ? Icons.wb_sunny_outlined
                              : Icons.wb_twilight_rounded,
                        ),
                        title: Text(
                          event.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: event.time == null
                            ? const Text('Not calculable for this date')
                            : event.estimated
                            ? const Text('High-latitude estimate')
                            : null,
                        trailing: Text(
                          '${_clock(event.time)}${event.time != null && event.time!.day != day.day ? ' *' : ''}',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (events.any((e) => e.time != null && e.time!.day != day.day))
                const Text('* Falls on an adjacent calendar day.'),
              if (events.any((e) => e.time == null))
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Some solar events do not occur here on this date. Please follow guidance from your local mosque.',
                  ),
                ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _settings,
                  child: Text(
                    '${config.method} · ${config.hanafi ? 'Hanafi' : 'Standard'}',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _remaining(Duration remaining) {
    final minutes = (remaining.inSeconds / 60).ceil();
    if (minutes < 60) return 'In $minutes min';
    return 'In ${minutes ~/ 60} h ${minutes % 60} min';
  }
}

class PrayerSetup extends StatefulWidget {
  const PrayerSetup({super.key, this.initial});
  final PrayerConfiguration? initial;
  @override
  State<PrayerSetup> createState() => _PrayerSetupState();
}

class _PrayerSetupState extends State<PrayerSetup> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      latitude = TextEditingController(),
      longitude = TextEditingController(),
      zone = TextEditingController(),
      query = TextEditingController();
  late String method = widget.initial?.method ?? 'MWL';
  late bool hanafi = widget.initial?.hanafi ?? false;
  late HighLatitudeRule high =
      widget.initial?.highLatitude ?? HighLatitudeRule.angle;
  late final offsets = {
    for (final n in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'])
      n: TextEditingController(text: '${widget.initial?.adjustments[n] ?? 0}'),
  };
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    PrayerSchedule.initialize();
    if (widget.initial != null) _setLocation(widget.initial!.location);
  }

  void _setLocation(PrayerLocation l) {
    name.text = l.name;
    latitude.text = '${l.latitude}';
    longitude.text = '${l.longitude}';
    zone.text = l.zone;
  }

  @override
  void dispose() {
    unawaited(
      prayerLocationChannel.invokeMethod<void>('cancel').catchError((_) {}),
    );
    for (final c in [
      name,
      latitude,
      longitude,
      zone,
      query,
      ...offsets.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _lookup(bool current) async {
    if (!current && query.text.trim().isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await prayerLocationChannel
          .invokeMapMethod<String, dynamic>(current ? 'locate' : 'search', {
            'query': query.text.trim(),
          });
      if (result == null) throw const FormatException('No location');
      final location = PrayerLocation.fromMap(result);
      if (mounted) setState(() => _setLocation(location));
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is PlatformException ? e.message : 'Location unavailable. Choose a city or enter coordinates and time zone below.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _save() {
    if (!form.currentState!.validate()) return;
    try {
      final location = PrayerLocation.fromMap({
        'name': name.text.trim(),
        'latitude': double.parse(latitude.text),
        'longitude': double.parse(longitude.text),
        'zone': zone.text.trim(),
      });
      Navigator.pop(
        context,
        PrayerConfiguration(
          location: location,
          method: method,
          hanafi: hanafi,
          highLatitude: high,
          adjustments: {
            for (final e in offsets.entries) e.key: int.parse(e.value.text),
          },
        ),
      );
    } catch (_) {
      setState(
        () => error =
            'Check the location and IANA time zone, such as America/New_York.',
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error!)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Prayer settings')),
    body: SafeArea(
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Location', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text(
              'City search uses Apple. Check your time zone before saving.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : () => _lookup(true),
              icon: const Icon(Icons.my_location),
              label: const Text('Use current location'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: query,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Search city and country',
                    ),
                    onSubmitted: (_) => _lookup(false),
                  ),
                ),
                IconButton(
                  onPressed: busy ? null : () => _lookup(false),
                  icon: const Icon(Icons.search),
                  tooltip: 'Search city',
                ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            DropdownButtonFormField<PrayerLocation>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Or choose an offline city',
              ),
              items: [
                for (final city in PrayerLocation.cities)
                  DropdownMenuItem(value: city, child: Text(city.name)),
              ],
              onChanged: busy
                  ? null
                  : (city) {
                      if (city != null) setState(() => _setLocation(city));
                    },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Location name'),
              validator: (v) => v!.trim().isEmpty ? 'Enter a location' : null,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: latitude,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) => _coordinate(v, 90),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: longitude,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) => _coordinate(v, 180),
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: zone,
              decoration: const InputDecoration(
                labelText: 'IANA time zone',
                hintText: 'America/New_York',
              ),
              autocorrect: false,
              validator: (v) => v!.trim().isEmpty ? 'Enter a time zone' : null,
            ),
            const SizedBox(height: 28),
            Text(
              'Calculation',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: method,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Method'),
              items: [
                for (final m in PrayerMethod.all)
                  DropdownMenuItem(value: m.code, child: Text(m.name)),
              ],
              onChanged: (v) => setState(() => method = v!),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hanafi Asr'),
              subtitle: const Text('Later Asr'),
              value: hanafi,
              onChanged: (v) => setState(() => hanafi = v),
            ),
            DropdownButtonFormField<HighLatitudeRule>(
              initialValue: high,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'High-latitude adjustment',
              ),
              items: const [
                DropdownMenuItem(
                  value: HighLatitudeRule.angle,
                  child: Text('Angle-based'),
                ),
                DropdownMenuItem(
                  value: HighLatitudeRule.middle,
                  child: Text('Middle of the night'),
                ),
                DropdownMenuItem(
                  value: HighLatitudeRule.seventh,
                  child: Text('One seventh of the night'),
                ),
                DropdownMenuItem(
                  value: HighLatitudeRule.none,
                  child: Text('None'),
                ),
              ],
              onChanged: (v) => setState(() => high = v!),
            ),
            if (PrayerMethod.byCode(method).ishaMinutes != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'This preset uses ${PrayerMethod.byCode(method).ishaMinutes!.round()} minutes after Maghrib for Isha. Ramadan changes are not automatic; use an adjustment if your mosque requires one.',
                ),
              ),
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Minute adjustments'),
              subtitle: const Text('Only if needed to match local guidance'),
              children: [
                for (final e in offsets.entries)
                  TextFormField(
                    controller: e.value,
                    decoration: InputDecoration(
                      labelText: '${e.key} · minutes (+/−)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n.abs() > 60
                          ? 'Use −60 to +60'
                          : null;
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : _save,
              child: const Text('Save prayer settings'),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
  String? _coordinate(String? value, int range) {
    final n = double.tryParse(value ?? '');
    return n == null || !n.isFinite || n.abs() > range
        ? 'Use −$range to $range'
        : null;
  }
}
