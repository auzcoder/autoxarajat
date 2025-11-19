import 'package:hive_flutter/hive_flutter.dart';

import 'models.dart';

List<RefuelEntry> loadEntries(Box box) {
  final raw = box.get('entries') as List<dynamic>? ?? [];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((e) => RefuelEntry.fromMap(e))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

Future<void> saveEntries(Box box, List<RefuelEntry> entries) async {
  final mapped = entries.map((e) => e.toMap()).toList();
  await box.put('entries', mapped);
}

/// Hozircha iCloud o‘rniga lokal ma’lumotni qaytaramiz.
/// Keyin real iCloud sync qo‘shsa bo‘ladi.
Future<List<RefuelEntry>> tryLoadFromICloud(Box box) async {
  return loadEntries(box);
}
