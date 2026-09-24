import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dua/dua_catalog.dart';
import '../prayer/prayer_schedule.dart';

const teacherDisclaimer =
    'Automatic tajwīd and pronunciation feedback can be wrong and does not replace a qualified Qur’an teacher.';

enum AppColorTheme { emerald, ocean, sand, plum }

enum AppAppearance { system, light, dark }

abstract interface class SettingsStore {
  Future<bool?> getBool(String key);
  Future<double?> getDouble(String key);
  Future<int?> getInt(String key);
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> setBool(String key, bool value);
  Future<void> setDouble(String key, double value);
  Future<void> setInt(String key, int value);
  Future<void> remove(String key);
}

class PreferencesSettingsStore implements SettingsStore {
  PreferencesSettingsStore(this.preferences);
  final SharedPreferencesAsync preferences;
  @override
  Future<String?> getString(String key) => preferences.getString(key);
  @override
  Future<void> setString(String key, String value) =>
      preferences.setString(key, value);
  @override
  Future<bool?> getBool(String key) => preferences.getBool(key);
  @override
  Future<double?> getDouble(String key) => preferences.getDouble(key);
  @override
  Future<int?> getInt(String key) => preferences.getInt(key);
  @override
  Future<void> setBool(String key, bool value) =>
      preferences.setBool(key, value);
  @override
  Future<void> setDouble(String key, double value) =>
      preferences.setDouble(key, value);
  @override
  Future<void> setInt(String key, int value) => preferences.setInt(key, value);
  @override
  Future<void> remove(String key) => preferences.remove(key);
}

class LocalSettings extends ChangeNotifier {
  LocalSettings(this.preferences);
  final SettingsStore preferences;
  bool acknowledged = false;
  bool followRecitation = false;
  double arabicSize = 36;
  int? bookmarkSurah;
  int? bookmarkAyah;
  AppColorTheme colorTheme = AppColorTheme.emerald;
  AppAppearance appearance = AppAppearance.system;
  PrayerConfiguration? prayerConfiguration;
  Future<void> setPrayerConfiguration(PrayerConfiguration value) async {
    await preferences.setString('prayer_configuration', value.encode());
    prayerConfiguration = value;
    notifyListeners();
  }

  final Set<String> favouriteDuas = {};
  Future<void> toggleDuaFavourite(String id) async {
    if (!DuaCatalog.entries.any((entry) => entry.id == id)) return;
    final selected = !favouriteDuas.contains(id);
    await preferences.setBool('dua_favourite_$id', selected);
    selected ? favouriteDuas.add(id) : favouriteDuas.remove(id);
    notifyListeners();
  }

  Future<void> load() async {
    final prayer = await preferences.getString('prayer_configuration');
    prayerConfiguration = null;
    if (prayer != null) {
      try {
        prayerConfiguration = PrayerConfiguration.decode(prayer);
      } catch (_) {
        // Invalid/obsolete settings require setup; never silently use another city.
      }
    }
    favouriteDuas.clear();
    for (final dua in DuaCatalog.entries) {
      if (await preferences.getBool('dua_favourite_${dua.id}') == true) {
        favouriteDuas.add(dua.id);
      }
    }
    followRecitation = await preferences.getBool('follow_recitation') ?? false;
    acknowledged =
        await preferences.getBool('teacher_disclaimer_acknowledged') ?? false;
    arabicSize = (await preferences.getDouble('arabic_size') ?? 36).clamp(
      28,
      56,
    );
    final savedBookmarkSurah = await preferences.getInt('bookmark_surah');
    final savedBookmarkAyah = await preferences.getInt('bookmark_ayah');
    if (savedBookmarkSurah != null && savedBookmarkAyah != null) {
      bookmarkSurah = savedBookmarkSurah.clamp(1, 114);
      bookmarkAyah = savedBookmarkAyah.clamp(1, 286);
    }
    colorTheme = _enumValue(
      AppColorTheme.values,
      await preferences.getInt('color_theme'),
      AppColorTheme.emerald,
    );
    appearance = _enumValue(
      AppAppearance.values,
      await preferences.getInt('appearance'),
      AppAppearance.system,
    );
  }

  static T _enumValue<T>(List<T> values, int? index, T fallback) =>
      index != null && index >= 0 && index < values.length
      ? values[index]
      : fallback;

  bool isBookmarked(int surah, int ayah) =>
      bookmarkSurah == surah && bookmarkAyah == ayah;

  Future<void> setBookmark(int surah, int ayah) async {
    bookmarkSurah = surah.clamp(1, 114);
    bookmarkAyah = ayah.clamp(1, 286);
    await preferences.setInt('bookmark_surah', bookmarkSurah!);
    await preferences.setInt('bookmark_ayah', bookmarkAyah!);
    notifyListeners();
  }

  Future<void> acknowledge() async {
    await preferences.setBool('teacher_disclaimer_acknowledged', true);
    acknowledged = true;
    notifyListeners();
  }

  Future<void> setArabicSize(double size) async {
    arabicSize = size;
    notifyListeners();
    await preferences.setDouble('arabic_size', size);
  }

  Future<void> setColorTheme(AppColorTheme value) async {
    colorTheme = value;
    notifyListeners();
    await preferences.setInt('color_theme', value.index);
  }

  Future<void> setAppearance(AppAppearance value) async {
    appearance = value;
    notifyListeners();
    await preferences.setInt('appearance', value.index);
  }

  Future<void> setFollowRecitation(bool value) async {
    followRecitation = value;
    await preferences.setBool('follow_recitation', value);
    notifyListeners();
  }

  Future<void> deleteAll() async {
    await preferences.remove('prayer_configuration');
    prayerConfiguration = null;
    for (final dua in DuaCatalog.entries) {
      await preferences.remove('dua_favourite_${dua.id}');
    }
    favouriteDuas.clear();
    await preferences.remove('follow_recitation');
    followRecitation = false;
    await preferences.remove('teacher_disclaimer_acknowledged');
    await preferences.remove('arabic_size');
    await preferences.remove('last_surah');
    await preferences.remove('last_ayah');
    await preferences.remove('bookmark_surah');
    await preferences.remove('bookmark_ayah');
    await preferences.remove('color_theme');
    await preferences.remove('appearance');
    acknowledged = false;
    arabicSize = 36;
    bookmarkSurah = null;
    bookmarkAyah = null;
    colorTheme = AppColorTheme.emerald;
    appearance = AppAppearance.system;
    notifyListeners();
  }
}
