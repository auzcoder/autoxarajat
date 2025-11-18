import 'dart:convert';

import 'package:flutter/services.dart';
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

  // iCloud sync
  final jsonStr = jsonEncode(mapped);
  final updatedAt = DateTime.now().toIso8601String();

  const channel = MethodChannel('icloud_sync');
  try {
    await channel.invokeMethod('saveEntries', {
      'entriesJson': jsonStr,
      'updatedAt': updatedAt,
    });
  } catch (_) {
    // iCloud bo‘lmasa ham, app lokal ishlayveradi
  }
}

Future<List<RefuelEntry>> tryLoadFromICloud(Box box) async {
  const channel = MethodChannel('icloud_sync');
  try {
    final result =
        await channel.invokeMethod<Map<dynamic, dynamic>>('loadEntries');
    if (result == null) return loadEntries(box);

    final entriesJson = result['entriesJson'] as String?;
    if (entriesJson == null || entriesJson.isEmpty) return loadEntries(box);

    final list = jsonDecode(entriesJson) as List<dynamic>;
    final entries = list
        .whereType<Map<String, dynamic>>()
        .map((e) => RefuelEntry.fromMap(e))
        .toList();
    await saveEntries(box, entries);
    return entries;
  } catch (_) {
    return loadEntries(box);
  }
}
