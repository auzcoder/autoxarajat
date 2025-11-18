import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AvtoXarajatApp());
}

class AvtoXarajatApp extends StatelessWidget {
  const AvtoXarajatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF16a34a), // yashil brend rangi
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'AvtoXarajat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
        ),
        cardTheme: CardTheme(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// Yoqilg'i yozuvi modeli (odometr bo'yicha)
class RefuelEntry {
  final String id;
  final DateTime dateTime;
  final double odometerKm; // paneldagi umumiy km
  final double liters; // qancha litr quyding
  final bool isFullTank; // shu quyishdan keyin balon FULL bo'ldimi?
  final double? pricePerLiter; // 1 litr narxi (ixtiyoriy)
  final String? note;

  RefuelEntry({
    required this.id,
    required this.dateTime,
    required this.odometerKm,
    required this.liters,
    required this.isFullTank,
    this.pricePerLiter,
    this.note,
  });

  double get totalCost =>
      pricePerLiter != null ? pricePerLiter! * liters : 0.0;

  // JSON ga aylantirish (saqlash uchun)
  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'odometerKm': odometerKm,
        'liters': liters,
        'isFullTank': isFullTank,
        'pricePerLiter': pricePerLiter,
        'note': note,
      };

  // JSON dan obyektga qaytarish
  factory RefuelEntry.fromJson(Map<String, dynamic> json) => RefuelEntry(
        id: json['id'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        odometerKm: (json['odometerKm'] as num).toDouble(),
        liters: (json['liters'] as num).toDouble(),
        isFullTank: json['isFullTank'] as bool,
        pricePerLiter: json['pricePerLiter'] == null
            ? null
            : (json['pricePerLiter'] as num).toDouble(),
        note: json['note'] as String?,
      );
}

/// Ikki FULL orasidagi sarf segmenti
class ConsumptionSegment {
  final RefuelEntry from;
  final RefuelEntry to;
  final double distanceKm;
  final double liters;
  final double cost;

  ConsumptionSegment({
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.liters,
    required this.cost,
  });

  double get per100 => liters / distanceKm * 100;
}

/// Oylik statistikaga agregatsiya
class MonthlyStats {
  final int year;
  final int month;
  final double distanceKm;
  final double liters;
  final double cost;

  MonthlyStats({
    required this.year,
    required this.month,
    required this.distanceKm,
    required this.liters,
    required this.cost,
  });

  String get label =>
      DateFormat('MMM yy').format(DateTime(year, month, 1));

  double get per100 =>
      distanceKm > 0 ? (liters / distanceKm * 100) : 0.0;
}

/// FULL-to-FULL segmentlar yasash
List<ConsumptionSegment> buildSegments(List<RefuelEntry> entries) {
  if (entries.length < 2) return [];

  final sorted = [...entries]
    ..sort((a, b) => a.odometerKm.compareTo(b.odometerKm));

  final segments = <ConsumptionSegment>[];
  int? lastFullIndex;

  for (int i = 0; i < sorted.length; i++) {
    final current = sorted[i];
    if (current.isFullTank) {
      if (lastFullIndex != null &&
          current.odometerKm > sorted[lastFullIndex].odometerKm) {
        final from = sorted[lastFullIndex];
        final to = current;
        final distance = to.odometerKm - from.odometerKm;
        double liters = 0;
        double cost = 0;
        for (int k = lastFullIndex + 1; k <= i; k++) {
          liters += sorted[k].liters;
          cost += sorted[k].totalCost;
        }
        if (distance > 0 && liters > 0) {
          segments.add(
            ConsumptionSegment(
              from: from,
              to: to,
              distanceKm: distance,
              liters: liters,
              cost: cost,
            ),
          );
        }
      }
      lastFullIndex = i;
    }
  }

  return segments;
}

/// Segmentlar bo'yicha oylik statistikani hisoblash
List<MonthlyStats> buildMonthlyStats(List<ConsumptionSegment> segments) {
  final map = <String, MonthlyStats>{};

  for (final s in segments) {
    final dt = s.to.dateTime;
    final key = '${dt.year}-${dt.month}';
    final existing = map[key];
    if (existing == null) {
      map[key] = MonthlyStats(
        year: dt.year,
        month: dt.month,
        distanceKm: s.distanceKm,
        liters: s.liters,
        cost: s.cost,
      );
    } else {
      map[key] = MonthlyStats(
        year: existing.year,
        month: existing.month,
        distanceKm: existing.distanceKm + s.distanceKm,
        liters: existing.liters + s.liters,
        cost: existing.cost + s.cost,
      );
    }
  }

  final list = map.values.toList();
  list.sort((a, b) {
    final da = DateTime(a.year, a.month);
    final db = DateTime(b.year, b.month);
    return da.compareTo(db);
  });
  return list;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // Sozlamalar
  double _tankCapacityLiters = 48; // Nexia 3 balon hajmi

  // Dastlabki test ma'lumotlar (keyin o'zingniki bilan to'ldirasan)
  final List<RefuelEntry> _entries = [
    RefuelEntry(
      id: 'e1',
      dateTime: DateTime(2025, 1, 1, 10, 0),
      odometerKm: 100000,
      liters: 23,
      isFullTank: true,
      pricePerLiter: 5_000, // misol uchun
      note: '268 km / 23 l',
    ),
    RefuelEntry(
      id: 'e2',
      dateTime: DateTime(2025, 1, 5, 9, 0),
      odometerKm: 100268,
      liters: 43,
      isFullTank: true,
      pricePerLiter: 5_000,
      note: '331 km / 43 l',
    ),
    RefuelEntry(
      id: 'e3',
      dateTime: DateTime(2025, 1, 10, 9, 30),
      odometerKm: 100599,
      liters: 44.7,
      isFullTank: true,
      pricePerLiter: 5_200,
      note: '368 km / 44.7 l',
    ),
    RefuelEntry(
      id: 'e4',
      dateTime: DateTime(2025, 1, 15, 8, 45),
      odometerKm: 100967,
      liters: 42,
      isFullTank: true,
      pricePerLiter: 5_200,
      note: '365 km / 42 l',
    ),
  ];

  final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  List<RefuelEntry> get _sortedEntries {
    final list = [..._entries];
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialEntries();
  }

  /// App ochilganda lokal + iCloud'dan o'qish
  Future<void> _loadInitialEntries() async {
    // 1) Lokal
    final localEntries = await StorageHelper.loadEntries();
    final localUpdatedAt = await StorageHelper.loadUpdatedAt();

    if (mounted && localEntries.isNotEmpty) {
      setState(() {
        _entries
          ..clear()
          ..addAll(localEntries);
      });
    }

    // 2) iCloud (agar bor bo'lsa, va yangiroq bo'lsa — ustidan yozamiz)
    final cloudState = await CloudSyncService.loadEntries();
    if (cloudState == null || cloudState.entries.isEmpty) {
      // Agar cloud bo'sh, lekin lokal bor bo'lsa – lokalni cloudga push qilamiz
      if (localEntries.isNotEmpty && localUpdatedAt != null) {
        await CloudSyncService.saveEntries(localEntries, localUpdatedAt);
      }
      return;
    }

    final cloudUpdatedAt = cloudState.updatedAt;
    final bool isCloudNewer;
    if (cloudUpdatedAt == null) {
      isCloudNewer = false;
    } else if (localUpdatedAt == null) {
      isCloudNewer = true;
    } else {
      isCloudNewer = cloudUpdatedAt.isAfter(localUpdatedAt);
    }

    if (isCloudNewer) {
      if (mounted) {
        setState(() {
          _entries
            ..clear()
            ..addAll(cloudState.entries);
        });
      }
      // Lokalni ham cloud'dan kelgan bilan yangilab qo'yamiz
      await StorageHelper.saveEntries(cloudState.entries);
    } else if (localEntries.isNotEmpty && localUpdatedAt != null) {
      // Aksincha bo'lsa – lokal yangiroq, cloud'ni yangilaymiz
      await CloudSyncService.saveEntries(localEntries, localUpdatedAt);
    }
  }

  /// Har safar o'zgarganda saqlash (lokal + iCloud)
  Future<void> _persistEntries() async {
    final updatedAt = await StorageHelper.saveEntries(_entries);
    await CloudSyncService.saveEntries(_entries, updatedAt);
  }

  // Yozuv qo'shish / tahrirlash
  void _addOrEditEntry({RefuelEntry? existing}) {
    final odoController = TextEditingController(
      text: existing != null ? existing.odometerKm.toStringAsFixed(0) : '',
    );
    final literController = TextEditingController(
      text: existing != null ? existing.liters.toString() : '',
    );
    final priceController = TextEditingController(
      text: existing?.pricePerLiter?.toString() ?? '',
    );
    final noteController =
        TextEditingController(text: existing?.note ?? '');
    bool isFull = existing?.isFullTank ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      existing == null
                          ? 'Yangi yoqilg\'i yozuvi'
                          : 'Yozuvni tahrirlash',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: odoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Odometr (km)',
                        hintText: 'Masalan: 123450',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: literController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quyilgan gaz (litr)',
                        hintText: 'Masalan: 34.5',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      decoration: const InputDecoration(
                        labelText: '1 litr narxi (so\'m)',
                        hintText: 'Masalan: 5000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Switch(
                          value: isFull,
                          onChanged: (v) {
                            setModalState(() {
                              isFull = v;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isFull
                                ? 'Balon to\'liq to\'ldi (FULL)'
                                : 'Qisman quyish (FULL emas)',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Izoh (ixtiyoriy)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final odo = double.tryParse(
                              odoController.text.trim());
                          final liters = double.tryParse(
                              literController.text.trim());
                          final price = double.tryParse(
                              priceController.text.trim());

                          if (odo == null || liters == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Odometr va litrni to\'g\'ri kiriting',
                                ),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            if (existing == null) {
                              _entries.add(
                                RefuelEntry(
                                  id: DateTime.now()
                                      .microsecondsSinceEpoch
                                      .toString(),
                                  dateTime: DateTime.now(),
                                  odometerKm: odo,
                                  liters: liters,
                                  isFullTank: isFull,
                                  pricePerLiter: price,
                                  note: noteController.text.isEmpty
                                      ? null
                                      : noteController.text,
                                ),
                              );
                            } else {
                              final index = _entries.indexWhere(
                                  (e) => e.id == existing.id);
                              if (index != -1) {
                                _entries[index] = RefuelEntry(
                                  id: existing.id,
                                  dateTime: existing.dateTime,
                                  odometerKm: odo,
                                  liters: liters,
                                  isFullTank: isFull,
                                  pricePerLiter: price,
                                  note: noteController.text.isEmpty
                                      ? null
                                      : noteController.text,
                                );
                              }
                            }
                          });

                          _persistEntries();
                          Navigator.of(ctx).pop();
                        },
                        icon: const Icon(Icons.save),
                        label: Text(
                          existing == null ? 'Saqlash' : 'Yangilash',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteEntry(RefuelEntry entry) {
    setState(() {
      _entries.removeWhere((e) => e.id == entry.id);
    });
    _persistEntries();
  }

  @override
  Widget build(BuildContext context) {
    final segments = buildSegments(_entries);
    final monthlyStats = buildMonthlyStats(segments);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AvtoXarajat'),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _EntriesTab(
            entries: _sortedEntries,
            dateFormat: _dateFormat,
            onEdit: _addOrEditEntry,
            onDelete: _deleteEntry,
          ),
          _StatsTab(
            entries: _entries,
            segments: segments,
            monthlyStats: monthlyStats,
            tankCapacityLiters: _tankCapacityLiters,
          ),
          _SettingsTab(
            tankCapacityLiters: _tankCapacityLiters,
            onTankCapacityChanged: (value) {
              setState(() {
                _tankCapacityLiters = value;
              });
              _persistEntries();
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Yozuvlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats_outlined),
            selectedIcon: Icon(Icons.query_stats),
            label: 'Statistika',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Sozlamalar',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => _addOrEditEntry(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

/// 1-tab: yozuvlar ro'yxati
class _EntriesTab extends StatelessWidget {
  final List<RefuelEntry> entries;
  final DateFormat dateFormat;
  final void Function({RefuelEntry? existing}) onEdit;
  final void Function(RefuelEntry entry) onDelete;

  const _EntriesTab({
    required this.entries,
    required this.dateFormat,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child:
            Text('Hozircha ma\'lumot yo\'q. + tugmasi bilan yozuv qo\'shing.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              radius: 22,
              backgroundColor:
                  e.isFullTank ? Colors.green.shade100 : Colors.orange.shade100,
              child: Icon(
                Icons.local_gas_station,
                color: e.isFullTank ? Colors.green.shade700 : Colors.orange,
              ),
            ),
            title: Text(
              '${e.liters.toStringAsFixed(1)} l  •  ${e.odometerKm.toStringAsFixed(0)} km',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${dateFormat.format(e.dateTime)}'
              '${e.isFullTank ? '\nFULL balon' : '\nQisman quyish'}'
              '${e.pricePerLiter != null ? '\n${e.totalCost.toStringAsFixed(0)} so\'m (taxminiy)' : ''}'
              '${e.note != null ? '\n${e.note}' : ''}',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit(existing: e);
                } else if (value == 'delete') {
                  onDelete(e);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Tahrirlash'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('O\'chirish'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 2-tab: Statistika + chartlar + oylik ma'lumotlar
class _StatsTab extends StatelessWidget {
  final List<RefuelEntry> entries;
  final List<ConsumptionSegment> segments;
  final List<MonthlyStats> monthlyStats;
  final double tankCapacityLiters;

  const _StatsTab({
    required this.entries,
    required this.segments,
    required this.monthlyStats,
    required this.tankCapacityLiters,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return const Center(
        child: Text(
          'Statistika uchun kamida 2 ta yozuv kerak.\nKamida 2 marta yoqilg\'i kiritib ko\'ring.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final totalLiters =
        entries.fold<double>(0, (sum, e) => sum + e.liters); // jami gaz (l)
    final totalCost =
        entries.fold<double>(0, (sum, e) => sum + e.totalCost); // jami xarajat

    final sortedByOdo = [...entries]
      ..sort((a, b) => a.odometerKm.compareTo(b.odometerKm));
    final totalDistance =
        sortedByOdo.last.odometerKm - sortedByOdo.first.odometerKm; // jami yo'l

    // FULL segmentlar bo'yicha o'rtacha sarf (agar bo'lsa)
    double avgPer100;
    if (segments.isNotEmpty) {
      final segDistance =
          segments.fold<double>(0, (sum, s) => sum + s.distanceKm);
      final segLiters =
          segments.fold<double>(0, (sum, s) => sum + s.liters);
      avgPer100 = segLiters / segDistance * 100;
    } else {
      avgPer100 = totalLiters / totalDistance * 100;
    }

    final maxPer100 = segments.isNotEmpty
        ? segments.map((s) => s.per100).reduce(max)
        : avgPer100;
    final minPer100 = segments.isNotEmpty
        ? segments.map((s) => s.per100).reduce(min)
        : avgPer100;

    final estimatedRange = avgPer100 > 0
        ? tankCapacityLiters / avgPer100 * 100
        : 0; // FULL balon bilan taxminiy yurish

    // So'nggi 30 kun uchun
    final now = DateTime.now();
    final last30 = entries.where(
      (e) => e.dateTime.isAfter(now.subtract(const Duration(days: 30))),
    );
    double last30Distance = 0;
    if (last30.length >= 2) {
      final byOdo = [...last30]
        ..sort((a, b) => a.odometerKm.compareTo(b.odometerKm));
      last30Distance = byOdo.last.odometerKm - byOdo.first.odometerKm;
    }
    final last30Liters =
        last30.fold<double>(0, (sum, e) => sum + e.liters);
    final last30Cost =
        last30.fold<double>(0, (sum, e) => sum + e.totalCost);

    // Segmentlar charti
    final spots = <FlSpot>[];
    for (int i = 0; i < segments.length; i++) {
      spots.add(FlSpot(i.toDouble(), segments[i].per100));
    }

    // Oylik chart nuqtalari (avg l/100km)
    final monthSpots = <FlSpot>[];
    for (int i = 0; i < monthlyStats.length; i++) {
      monthSpots.add(FlSpot(i.toDouble(), monthlyStats[i].per100));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(
                label: 'Jami yo‘l',
                value: totalDistance.toStringAsFixed(0),
                unit: 'km',
              ),
              _StatCard(
                label: 'Jami gaz',
                value: totalLiters.toStringAsFixed(1),
                unit: 'l',
              ),
              _StatCard(
                label: 'O‘rtacha sarf',
                value: avgPer100.toStringAsFixed(1),
                unit: 'l / 100km',
              ),
              _StatCard(
                label: 'FULL balon yurishi',
                value: estimatedRange.toStringAsFixed(0),
                unit: 'km (taxminiy)',
              ),
              _StatCard(
                label: 'Jami xarajat',
                value: totalCost.toStringAsFixed(0),
                unit: 'so‘m',
              ),
              _StatCard(
                label: 'So‘nggi 30 kun',
                value: last30Distance.toStringAsFixed(0),
                unit: 'km / ${last30Cost.toStringAsFixed(0)} so‘m',
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (segments.isNotEmpty)
            _ChartCard(
              title: 'FULL segmentlar bo\'yicha sarf (l/100km)',
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: max(0, (spots.length - 1).toDouble()),
                  minY: (minPer100 * 0.8),
                  maxY: (maxPer100 * 1.2),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= segments.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        applyCutOffY: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (monthlyStats.isNotEmpty)
            _ChartCard(
              title: 'Oylik o‘rtacha sarf (l/100km)',
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX:
                      max(0, (monthSpots.length - 1).toDouble()),
                  minY: monthlyStats
                          .map((m) => m.per100)
                          .reduce(min) *
                      0.8,
                  maxY: monthlyStats
                          .map((m) => m.per100)
                          .reduce(max) *
                      1.2,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= monthlyStats.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              monthlyStats[idx].label,
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: monthSpots,
                      isCurved: true,
                      dotData: const FlDotData(show: true),
                      belowBarData:
                          BarAreaData(show: true, applyCutOffY: true),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (monthlyStats.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Oylik ma\'lumotlar',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 8),
          if (monthlyStats.isNotEmpty)
            Column(
              children: monthlyStats.map((m) {
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(m.label),
                    subtitle: Text(
                      'Yo‘l: ${m.distanceKm.toStringAsFixed(0)} km  •  '
                      'Gaz: ${m.liters.toStringAsFixed(1)} l\n'
                      'Sarf: ${m.per100.toStringAsFixed(1)} l/100km',
                    ),
                    trailing: Text(
                      '${m.cost.toStringAsFixed(0)}\nso‘m',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 170,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer,
              colorScheme.secondaryContainer,
            ],
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onPrimaryContainer
                    .withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onPrimaryContainer
                    .withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3-tab: Sozlamalar (hozircha balon hajmi)
class _SettingsTab extends StatelessWidget {
  final double tankCapacityLiters;
  final ValueChanged<double> onTankCapacityChanged;

  const _SettingsTab({
    required this.tankCapacityLiters,
    required this.onTankCapacityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final controller =
        TextEditingController(text: tankCapacityLiters.toStringAsFixed(1));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const Text(
            'Sozlamalar',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Balon hajmi (litr)',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final value =
                              double.tryParse(controller.text.trim());
                          if (value == null || value <= 0) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Balon hajmini to\'g\'ri kiriting (masalan 48).'),
                              ),
                            );
                            return;
                          }
                          onTankCapacityChanged(value);
                          FocusScope.of(context).unfocus();
                        },
                        child: const Text('Saqlash'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Bu qiymat bo\'yicha FULL balon bilan taxminiy yurish masofasi hisoblanadi.',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: const Padding(
              padding: EdgeInsets.all(14.0),
              child: Text(
                'Keyinchalik bu yerga tema (dark mode), valyuta, narxlar, '
                'va iCloud sync sozlamalarini qo\'shimcha nazorat qilib qo\'shish mumkin.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ma'lumotlarni telefon ichida saqlash/yuklash uchun yordamchi
class StorageHelper {
  static const _keyEntries = 'refuel_entries';
  static const _keyUpdatedAt = 'refuel_entries_updated_at';

  // Barcha yozuvlarni saqlash
  static Future<DateTime> saveEntries(List<RefuelEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final listMap = entries.map((e) => e.toJson()).toList();
    final jsonStr = jsonEncode(listMap);
    final now = DateTime.now();
    await prefs.setString(_keyEntries, jsonStr);
    await prefs.setString(_keyUpdatedAt, now.toIso8601String());
    return now;
  }

  // Barcha yozuvlarni o'qish
  static Future<List<RefuelEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyEntries);
    if (jsonStr == null) return [];
    final List<dynamic> list = jsonDecode(jsonStr);
    return list
        .map((e) => RefuelEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<DateTime?> loadUpdatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyUpdatedAt);
    if (str == null || str.isEmpty) return null;
    return DateTime.tryParse(str);
  }
}

/// iCloud bilan sinxronlash (NSUbiquitousKeyValueStore)
class CloudSyncService {
  static const _channel = MethodChannel('icloud_sync');

  static Future<void> saveEntries(
      List<RefuelEntry> entries, DateTime updatedAt) async {
    try {
      final jsonStr =
          jsonEncode(entries.map((e) => e.toJson()).toList());
      await _channel.invokeMethod('saveEntries', {
        'entriesJson': jsonStr,
        'updatedAt': updatedAt.toIso8601String(),
      });
    } catch (e) {
      // iCloud ishlamasa ham app ishlashda davom etadi
      print('Cloud save error: $e');
    }
  }

  static Future<_CloudState?> loadEntries() async {
    try {
      final result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>(
              'loadEntries');

      if (result == null) return null;
      final jsonStr = (result['entriesJson'] as String?) ?? '';
      final updatedAtStr =
          (result['updatedAt'] as String?) ?? '';

      if (jsonStr.isEmpty) return null;

      final List<dynamic> list = jsonDecode(jsonStr);
      final entries = list
          .map((e) =>
              RefuelEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final updatedAt = updatedAtStr.isNotEmpty
          ? DateTime.tryParse(updatedAtStr)
          : null;

      return _CloudState(entries: entries, updatedAt: updatedAt);
    } catch (e) {
      print('Cloud load error: $e');
      return null;
    }
  }
}

class _CloudState {
  final List<RefuelEntry> entries;
  final DateTime? updatedAt;

  _CloudState({required this.entries, required this.updatedAt});
}
