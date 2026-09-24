// SPDX-License-Identifier: LGPL-3.0-only
// Adapted from MAWAQIT/prayer-times, revision 640157265aaa4e71e33b8aa718f36f35fb99eb92.
// Original astronomy: Hamid Zarrabi-Zadeh (PrayTimes.org); PHP: Meezaan-ud-Din.
// Changes: Dart port, deterministic Asr date, unavailable polar events, typed results.
import 'dart:math' as math;

enum HighLatitudeRule { angle, middle, seventh, none }

class PrayerMethod {
  const PrayerMethod(
    this.code,
    this.name,
    this.fajr,
    this.isha, {
    this.ishaMinutes,
    this.maghribAngle,
    this.maghribMinutes = 0,
  });
  final String code, name;
  final double fajr, isha;
  final double? ishaMinutes, maghribAngle;
  final double maghribMinutes;
  static const all = [
    PrayerMethod('MWL', 'Muslim World League', 18, 17),
    PrayerMethod('ISNA', 'North America · ISNA', 15, 15),
    PrayerMethod('KARACHI', 'Karachi', 18, 18),
    PrayerMethod('EGYPT', 'Egypt', 19.5, 17.5),
    PrayerMethod('MAKKAH', 'Umm al-Qura · Makkah', 18.5, 0, ishaMinutes: 90),
    PrayerMethod('GULF', 'Gulf Region', 19.5, 0, ishaMinutes: 90),
    PrayerMethod('KUWAIT', 'Kuwait', 18, 17.5),
    PrayerMethod('QATAR', 'Qatar', 18, 0, ishaMinutes: 90),
    PrayerMethod('SINGAPORE', 'Singapore', 20, 18),
    PrayerMethod('FRANCE', 'France · UOIF', 12, 12),
    PrayerMethod('TURKEY', 'Turkey · experimental', 18, 17),
    PrayerMethod('RUSSIA', 'Russia', 16, 15),
    PrayerMethod('DUBAI', 'Dubai · experimental', 18.2, 18.2),
    PrayerMethod('JAKIM', 'Malaysia · JAKIM', 20, 18),
    PrayerMethod('TUNISIA', 'Tunisia', 18, 18),
    PrayerMethod('ALGERIA', 'Algeria', 18, 17),
    PrayerMethod('KEMENAG', 'Indonesia · Kemenag', 20, 18),
    PrayerMethod('MOROCCO', 'Morocco', 19, 17),
    PrayerMethod(
      'PORTUGAL',
      'Portugal',
      18,
      0,
      ishaMinutes: 77,
      maghribMinutes: 3,
    ),
    PrayerMethod('JORDAN', 'Jordan', 18, 18, maghribMinutes: 5),
    PrayerMethod('TEHRAN', 'Tehran', 17.7, 14, maghribAngle: 4.5),
    PrayerMethod('JAFARI', 'Jaʿfari · Leva Institute', 16, 14, maghribAngle: 4),
  ];
  static PrayerMethod byCode(String code) =>
      all.firstWhere((m) => m.code == code);
}

class CalculatedPrayerTime {
  const CalculatedPrayerTime(this.name, this.minutes, {this.estimated = false});
  final String name;
  // Unwrapped minutes from the selected civil date: may be <0 or >=1440.
  final int? minutes;
  final bool estimated;
  bool get isPrayer => name != 'Sunrise';
}

class MawaqitCalculator {
  List<CalculatedPrayerTime> calculate({
    required DateTime date,
    required double latitude,
    required double longitude,
    required double utcOffsetHours,
    required PrayerMethod method,
    bool hanafi = false,
    HighLatitudeRule highLatitude = HighLatitudeRule.angle,
    Map<String, int> adjustments = const {},
  }) {
    if (!latitude.isFinite ||
        latitude.abs() > 90 ||
        !longitude.isFinite ||
        longitude.abs() > 180 ||
        !utcOffsetHours.isFinite ||
        utcOffsetHours.abs() > 14) {
      throw ArgumentError('Invalid coordinates or time zone offset');
    }
    final jd = _julian(date) - longitude / 360;
    double noon(double portion) => _fix(12 - _sun(jd + portion).equation, 24);
    double angleTime(double angle, double portion, bool before) {
      final declination = _sun(jd + portion).declination;
      final ratio =
          (-_sin(angle) - _sin(declination) * _sin(latitude)) /
          (_cos(declination) * _cos(latitude));
      // Do not turn a missing sunrise/sunset into noon or midnight by clamping.
      if (!ratio.isFinite || ratio.abs() > 1) return double.nan;
      final delta = math.acos(ratio) * 180 / math.pi / 15;
      return noon(portion) + (before ? -delta : delta);
    }

    final asrDeclination = _sun(jd + 13 / 24).declination;
    final asrAngle =
        -math.atan(
          1 / ((hanafi ? 2 : 1) + _tan((latitude - asrDeclination).abs())),
        ) *
        180 /
        math.pi;
    final offset = utcOffsetHours - longitude / 15;
    final values = <String, double>{
      'Fajr': angleTime(method.fajr, 5 / 24, true) + offset,
      'Sunrise': angleTime(0.833, 6 / 24, true) + offset,
      'Dhuhr': noon(12 / 24) + offset,
      'Asr': angleTime(asrAngle, 13 / 24, false) + offset,
      'Maghrib': angleTime(method.maghribAngle ?? 0, 18 / 24, false) + offset,
      'Isha':
          angleTime(method.ishaMinutes ?? method.isha, 18 / 24, false) + offset,
    };
    final sunset = angleTime(0.833, 18 / 24, false) + offset;
    final sunrise = values['Sunrise']!;
    final night = _fix(sunrise - sunset, 24);
    final estimated = <String>{};
    void limitNight(String name, double angle, double base, bool before) {
      if (highLatitude == HighLatitudeRule.none || !night.isFinite) return;
      final portion =
          switch (highLatitude) {
            HighLatitudeRule.angle => angle / 60,
            HighLatitudeRule.middle => 0.5,
            HighLatitudeRule.seventh => 1 / 7,
            HighLatitudeRule.none => 0.0,
          } *
          night;
      final time = values[name]!;
      final distance = _fix(before ? base - time : time - base, 24);
      if (!time.isFinite || distance > portion) {
        values[name] = base + (before ? -portion : portion);
        estimated.add(name);
      }
    }

    limitNight('Fajr', method.fajr, sunrise, true);
    if (method.ishaMinutes == null) {
      limitNight('Isha', method.isha, sunset, false);
    }
    if (method.maghribAngle != null) {
      limitNight('Maghrib', method.maghribAngle!, sunset, false);
    } else {
      values['Maghrib'] = sunset + method.maghribMinutes / 60;
    }
    if (method.ishaMinutes != null) {
      values['Isha'] = values['Maghrib']! + method.ishaMinutes! / 60;
    }
    return [
      for (final entry in values.entries)
        CalculatedPrayerTime(
          entry.key,
          entry.value.isFinite
              ? (entry.value * 60 + 0.5).floor() + (adjustments[entry.key] ?? 0)
              : null,
          estimated: estimated.contains(entry.key),
        ),
    ];
  }
}

double _sin(double value) => math.sin(value * math.pi / 180);
double _cos(double value) => math.cos(value * math.pi / 180);
double _tan(double value) => math.tan(value * math.pi / 180);
double _fix(double value, double range) =>
    value.isFinite ? value % range : double.nan;
({double declination, double equation}) _sun(double jd) {
  final d = jd - 2451545;
  final g = _fix(357.529 + 0.98560028 * d, 360);
  final q = _fix(280.459 + 0.98564736 * d, 360);
  final l = _fix(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g), 360);
  final e = 23.439 - 0.00000036 * d;
  final ra = math.atan2(_cos(e) * _sin(l), _cos(l)) * 180 / math.pi / 15;
  return (
    declination: math.asin(_sin(e) * _sin(l)) * 180 / math.pi,
    equation: q / 15 - _fix(ra, 24),
  );
}

double _julian(DateTime date) {
  var year = date.year, month = date.month;
  if (month <= 2) {
    year--;
    month += 12;
  }
  final a = (year / 100).floor();
  return (365.25 * (year + 4716)).floor() +
      (30.6001 * (month + 1)).floor() +
      date.day +
      2 -
      a +
      (a / 4).floor() -
      1524.5;
}
