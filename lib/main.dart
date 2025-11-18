import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const AvtoXarajatApp());
}

class AvtoXarajatApp extends StatelessWidget {
  const AvtoXarajatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF16a34a), // yashil-ishil brend rang
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
  final String? note;

  RefuelEntry({
    required this.id,
    required this.dateTime,
    required this.odometerKm,
    required this.liters,
    required this.isFullTank,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'odometerKm': odometerKm,
        'liters': liters,
        'isFullTank': isFullTank,
        'note': note,
      };

  factory RefuelEntry.fromJson(Map<String, dynamic> json) => RefuelEntry(
        id: json['id'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        odometerKm: (json['odometerKm'] as num).toDouble(),
        liters: (json['liters'] as num).toDouble(),
        isFullTank: json['isFullTank'] as bool,
        note: json['note'] as String?,
      );
}

/// Ikki FULL orasidagi sarf segmenti
class ConsumptionSegment {
  final RefuelEntry from;
  final RefuelEntry to;
  final double distanceKm;
  final double liters;

  ConsumptionSegment({
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.liters,
  });

  double get per100 => liters / distanceKm * 100;
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
        for (int k = lastFullIndex + 1; k <= i; k++) {
          liters += sorted[k].liters;
        }
        if (distance > 0 && liters > 0) {
          segments.add(
            ConsumptionSegment(
              from: from,
              to: to,
              distanceKm: distance,
              liters: liters,
            ),
          );
        }
      }
      lastFullIndex = i;
    }
  }

  return segments;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // Sozlamalar (hozircha faqat RAMda, keyin Hive/CloudKit bilan saqlaymiz)
  double _tankCapacityLiters = 48; // Nexia 3 balon ~48 l deb olaylik

  // TEST ma'lumotlar (odometr sun'iy, lekin real sarfga yaqin)
  final List<RefuelEntry> _entries = [
    RefuelEntry(
      id: 'e1',
      dateTime: DateTime(2025, 1, 1, 10, 0),
      odometerKm: 100000,
      liters: 23,
      isFullTank: true,
      note: '268 km / 23 l',
    ),
    RefuelEntry(
      id: 'e2',
      dateTime: DateTime(2025, 1, 5, 9, 0),
      odometerKm: 100268,
      liters: 43,
      isFullTank: true,
      note: '331 km / 43 l',
    ),
    RefuelEntry(
      id: 'e3',
      dateTime: DateTime(2025, 1, 10, 9, 30),
      odometerKm: 100599,
      liters: 44.7,
      isFullTank: true,
      note: '368 km / 44.7 l',
    ),
    RefuelEntry(
      id: 'e4',
      dateTime: DateTime(2025, 1, 15, 8, 45),
      odometerKm: 100967,
      liters: 42,
      isFullTank: true,
      note: '365 km / 42 l',
    ),
    RefuelEntry(
      id: 'e5',
      dateTime: DateTime(2025, 1, 20, 8, 20),
      odometerKm: 101332,
      liters: 34,
      isFullTank: true,
      note: '284 km / 34 l',
    ),
    RefuelEntry(
      id: 'e6',
      dateTime: DateTime(2025, 1, 25, 8, 15),
      odometerKm: 101616,
      liters: 44,
      isFullTank: true,
      note: '364 km / 44 l',
    ),
  ];

  final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  List<RefuelEntry> get _sortedEntries {
    final list = [..._entries];
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  // Yangi yozuv / tahrirlash (FULL switchni to'g'ri ishlashi uchun StatefulBuilder ishlatyapmiz)
  void _addOrEditEntry({RefuelEntry? existing}) {
    final odoController = TextEditingController(
      text: existing != null ? existing.odometerKm.toStringAsFixed(0) : '',
    );
    final literController = TextEditingController(
      text: existing != null ? existing.liters.toString() : '',
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
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Quyilgan gaz (litr)',
                      hintText: 'Masalan: 34.5',
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
                            isFull = v; // faqat shu bottom sheet ichida yangilanadi
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
                        final odo =
                            double.tryParse(odoController.text.trim());
                        final liters =
                            double.tryParse(literController.text.trim());
                        if (odo == null || liters == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Odometr va litrni to\'g\'ri kiriting'),
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
                                note: noteController.text.isEmpty
                                    ? null
                                    : noteController.text,
                              );
                            }
                          }
                        });

                        Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.save),
                      label: Text(
                          existing == null ? 'Saqlash' : 'Yangilash'),
                    ),
                  ),
                ],
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
  }

  @override
  Widget build(BuildContext context) {
    final segments = buildSegments(_entries);

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
            tankCapacityLiters: _tankCapacityLiters,
          ),
          _SettingsTab(
            tankCapacityLiters: _tankCapacityLiters,
            onTankCapacityChanged: (value) {
              setState(() {
                _tankCapacityLiters = value;
              });
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
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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

/// 2-tab: Statistika + chart
class _StatsTab extends StatelessWidget {
  final List<RefuelEntry> entries;
  final List<ConsumptionSegment> segments;
  final double tankCapacityLiters;

  const _StatsTab({
    required this.entries,
    required this.segments,
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

    // Chart nuqtalari
    final spots = <FlSpot>[];
    for (int i = 0; i < segments.length; i++) {
      spots.add(FlSpot(i.toDouble(), segments[i].per100));
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
                label: 'Yozuvlar soni',
                value: entries.length.toString(),
                unit: 'ta',
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (segments.isNotEmpty)
            SizedBox(
              height: 260,
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (spots.length - 1).toDouble(),
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
                          belowBarData:
                              BarAreaData(show: true, applyCutOffY: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            const Text(
              'FULL balon yozuvlari bo\'yicha chart uchun kamida 2 ta FULL segment kerak.',
              textAlign: TextAlign.center,
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
                color: colorScheme.onPrimaryContainer.withOpacity(0.8),
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
                color: colorScheme.onPrimaryContainer.withOpacity(0.8),
              ),
            ),
          ],
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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Balon hajmi (litr)',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                            ScaffoldMessenger.of(context).showSnackBar(
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
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14.0),
              child: Text(
                'Keyinchalik bu yerga mavzu (dark mode), valyuta, '
                'narxlar va iCloud sync sozlamalarini qo\'shamiz.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
