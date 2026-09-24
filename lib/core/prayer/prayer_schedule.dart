import 'dart:convert';

import 'package:timezone/data/latest_all.dart' as database;
import 'package:timezone/timezone.dart' as tz;

import 'mawaqit_calculator.dart';

class PrayerLocation {
  const PrayerLocation(this.name, this.latitude, this.longitude, this.zone);
  final String name, zone;
  final double latitude, longitude;
  static const cities = [
    PrayerLocation('New York', 40.7128, -74.0060, 'America/New_York'),
    PrayerLocation('Toronto', 43.6532, -79.3832, 'America/Toronto'),
    PrayerLocation('London', 51.5074, -0.1278, 'Europe/London'),
    PrayerLocation('Paris', 48.8566, 2.3522, 'Europe/Paris'),
    PrayerLocation('Makkah', 21.3891, 39.8579, 'Asia/Riyadh'),
    PrayerLocation('Dubai', 25.2048, 55.2708, 'Asia/Dubai'),
    PrayerLocation('Karachi', 24.8607, 67.0011, 'Asia/Karachi'),
    PrayerLocation('Lahore', 31.5204, 74.3587, 'Asia/Karachi'),
    PrayerLocation('Sydney', -33.8688, 151.2093, 'Australia/Sydney'),
  ];
  factory PrayerLocation.fromMap(Map<dynamic, dynamic> value) {
    final result = PrayerLocation(
      value['name'] as String,
      (value['latitude'] as num).toDouble(),
      (value['longitude'] as num).toDouble(),
      value['zone'] as String,
    );
    if (result.name.trim().isEmpty ||
        !result.latitude.isFinite ||
        !result.longitude.isFinite ||
        result.latitude.abs() > 90 ||
        result.longitude.abs() > 180) {
      throw const FormatException('Invalid location');
    }
    PrayerSchedule.initialize();
    tz.getLocation(result.zone);
    return result;
  }
  Map<String, dynamic> toMap() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'zone': zone,
  };
}

class PrayerConfiguration {
  const PrayerConfiguration({
    required this.location,
    this.method = 'MWL',
    this.hanafi = false,
    this.highLatitude = HighLatitudeRule.angle,
    this.adjustments = const {},
  });
  final PrayerLocation location;
  final String method;
  final bool hanafi;
  final HighLatitudeRule highLatitude;
  final Map<String, int> adjustments;
  String encode() => jsonEncode({
    'location': location.toMap(),
    'method': method,
    'hanafi': hanafi,
    'highLatitude': highLatitude.name,
    'adjustments': adjustments,
  });
  factory PrayerConfiguration.decode(String value) {
    final data = jsonDecode(value) as Map;
    final method = data['method'] as String;
    PrayerMethod.byCode(method);
    final adjustments = Map<String, int>.from(
      data['adjustments'] as Map? ?? {},
    );
    if (adjustments.values.any((n) => n.abs() > 60)) {
      throw const FormatException('Invalid adjustment');
    }
    return PrayerConfiguration(
      location: PrayerLocation.fromMap(data['location'] as Map),
      method: method,
      hanafi: data['hanafi'] as bool,
      highLatitude: HighLatitudeRule.values.byName(
        data['highLatitude'] as String,
      ),
      adjustments: adjustments,
    );
  }
}

class PrayerEvent {
  const PrayerEvent(this.name, this.time, this.estimated);
  final String name;
  final tz.TZDateTime? time;
  final bool estimated;
}

class PrayerSchedule {
  PrayerSchedule(this.configuration) {
    initialize();
  }
  final PrayerConfiguration configuration;
  static bool _initialized = false;
  static void initialize() {
    if (!_initialized) {
      database.initializeTimeZones();
      _initialized = true;
    }
  }

  tz.Location get zone => tz.getLocation(configuration.location.zone);
  tz.TZDateTime localNow(DateTime now) => tz.TZDateTime.from(now, zone);
  List<PrayerEvent> forDate(DateTime day) {
    final noon = tz.TZDateTime(zone, day.year, day.month, day.day, 12);
    final offset = noon.timeZoneOffset;
    final times = MawaqitCalculator().calculate(
      date: day,
      latitude: configuration.location.latitude,
      longitude: configuration.location.longitude,
      utcOffsetHours: offset.inSeconds / 3600,
      method: PrayerMethod.byCode(configuration.method),
      hanafi: configuration.hanafi,
      highLatitude: configuration.highLatitude,
      adjustments: configuration.adjustments,
    );
    return [
      for (final t in times)
        PrayerEvent(
          t.name,
          t.minutes == null
              ? null
              :
                // Convert from solar-derived time using the calculation offset. This
                // preserves actual instants if a DST change occurs earlier in this day.
                tz.TZDateTime.from(
                  DateTime.utc(
                    day.year,
                    day.month,
                    day.day,
                  ).add(Duration(minutes: t.minutes!)).subtract(offset),
                  zone,
                ),
          t.estimated,
        ),
    ];
  }

  PrayerEvent? next(DateTime now) {
    final today = localNow(now);
    final events =
        [
              ...forDate(DateTime(today.year, today.month, today.day - 1)),
              ...forDate(today),
              ...forDate(DateTime(today.year, today.month, today.day + 1)),
            ]
            .where(
              (e) =>
                  e.name != 'Sunrise' && e.time != null && e.time!.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.time!.compareTo(b.time!));
    return events.isEmpty ? null : events.first;
  }
}
