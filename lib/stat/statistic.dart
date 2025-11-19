import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/models.dart';
import '../core/storage.dart';

enum StatsRange {
  week,
  month,
  year,
}

class StatsScreen extends StatefulWidget {
  final Box box;
  final AppProfile profile;
  const StatsScreen({super.key, required this.box, required this.profile});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatsRange _range = StatsRange.month;

  List<RefuelEntry> _filterByProfilePlate(List<RefuelEntry> entries) {
    final plate = widget.profile.plateNumber;
    if (plate == null || plate.isEmpty) {
      return entries
          .where((e) => e.plateNumber == null || e.plateNumber!.isEmpty)
          .toList();
    }
    return entries.where((e) => e.plateNumber == plate).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = loadEntries(widget.box);
    final entries = _filterByProfilePlate(allEntries);
    final now = DateTime.now();

    bool inRange(DateTime d) {
      final diff =
          now.difference(DateTime(d.year, d.month, d.day)).inDays;
      switch (_range) {
        case StatsRange.week:
          return diff <= 7;
        case StatsRange.month:
          return diff <= 31;
        case StatsRange.year:
          return diff <= 365;
      }
    }

    final filtered = entries.where((e) => inRange(e.date)).toList();

    // Sana bo‘yicha guruhlash (xarajat / km uchun)
    final Map<DateTime, double> groupedCosts = {};
    final Map<DateTime, double> groupedDistance = {};

    for (final e in filtered) {
      late DateTime key;
      switch (_range) {
        case StatsRange.week:
        case StatsRange.month:
          key = DateTime(e.date.year, e.date.month, e.date.day);
          break;
        case StatsRange.year:
          key = DateTime(e.date.year, e.date.month);
          break;
      }
      groupedCosts[key] = (groupedCosts[key] ?? 0) + e.totalCost;
      groupedDistance[key] = (groupedDistance[key] ?? 0) + e.distanceKm;
    }

    final sortedKeys = groupedCosts.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    final labels = sortedKeys.map((d) {
      switch (_range) {
        case StatsRange.week:
        case StatsRange.month:
          return DateFormat('dd.MM').format(d);
        case StatsRange.year:
          return DateFormat('MM.yyyy').format(d);
      }
    }).toList();

    final totalCost =
        filtered.fold<double>(0, (p, e) => p + e.totalCost);
    final totalDistance =
        filtered.fold<double>(0, (p, e) => p + e.distanceKm);
    final consList = filtered
        .map((e) => e.consumptionPer100)
        .whereType<double>()
        .toList();
    final avgCons = consList.isEmpty
        ? null
        : consList.reduce((a, b) => a + b) / consList.length;

    final avgCostPerKm =
        totalDistance > 0 ? totalCost / totalDistance : null;

    // km bo‘yicha yoqilg‘i sarfi uchun chart ma’lumotlari:
    // masofa bo‘yicha cumulative km vs L/100km
    final consEntries = filtered
        .where((e) => e.consumptionPer100 != null)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    double cumKm = 0;
    final List<FlSpot> consSpots = [];
    for (final e in consEntries) {
      cumKm += e.distanceKm;
      consSpots.add(
        FlSpot(cumKm, e.consumptionPer100!),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistika',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          ToggleButtons(
            isSelected: [
              _range == StatsRange.week,
              _range == StatsRange.month,
              _range == StatsRange.year
            ],
            borderRadius: BorderRadius.circular(999),
            onPressed: (i) {
              setState(() {
                _range = StatsRange.values[i];
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('7 kun'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('Oy'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('Yil'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          /// 1-chart: vaqt bo‘yicha xarajat
          Text(
            'Vaqt bo‘yicha jami xarajat',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: labels.isEmpty
                ? const Center(
                    child: Text('Bu davr uchun ma’lumot yo‘q.'),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < labels.length; i++)
                              FlSpot(
                                i.toDouble(),
                                groupedCosts[sortedKeys[i]] ?? 0,
                              )
                          ],
                          isCurved: true,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 ||
                                  index >= labels.length) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding:
                                    const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  labels[index],
                                  style:
                                      const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 20),

          /// 2-chart: km bo‘yicha yoqilg‘i sarfi
          Text(
            'Masofa bo‘yicha yoqilg‘i sarfi (L/100km)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: consSpots.isEmpty
                ? const Center(
                    child: Text(
                      'Sarflarni ko‘rish uchun masofa va litr kiritilgan yozuvlar kerak.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      lineBarsData: [
                        LineChartBarData(
                          spots: consSpots,
                          isCurved: true,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval:
                                consSpots.isEmpty ? 1 : consSpots.last.x / 4,
                            getTitlesWidget: (value, meta) {
                              if (value < 0) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding:
                                    const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${value.toStringAsFixed(0)} km',
                                  style:
                                      const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _StatCardMini(
                  title: 'Jami xarajat',
                  value: '${totalCost.toStringAsFixed(0)} so‘m',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCardMini(
                  title: 'Jami masofa',
                  value: '${totalDistance.toStringAsFixed(0)} km',
                  icon: Icons.route,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCardMini(
                  title: '1 km narxi',
                  value: avgCostPerKm == null
                      ? '—'
                      : '${avgCostPerKm.toStringAsFixed(0)} so‘m',
                  icon: Icons.price_check,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCardMini(
                  title: 'O‘rtacha sarf',
                  value: avgCons == null
                      ? '—'
                      : '${avgCons.toStringAsFixed(1)} L/100km',
                  icon: Icons.speed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCardMini extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCardMini({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? const Color(0xFF020617) : Colors.white,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
            child:
                Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
