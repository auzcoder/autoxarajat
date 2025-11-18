import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/models.dart';
import '../core/storage.dart';

import 'package:hive_flutter/hive_flutter.dart';


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

  @override
  Widget build(BuildContext context) {
    final entries = loadEntries(widget.box);
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

    final Map<String, double> groupedCosts = {};
    for (final e in filtered) {
      late String key;
      switch (_range) {
        case StatsRange.week:
        case StatsRange.month:
          key = DateFormat('dd.MM').format(e.date);
          break;
        case StatsRange.year:
          key = DateFormat('MM.yyyy').format(
            DateTime(e.date.year, e.date.month),
          );
          break;
      }
      groupedCosts[key] = (groupedCosts[key] ?? 0) + e.totalCost;
    }

    final labels = groupedCosts.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    final totalCost =
        filtered.fold<double>(0, (p, e) => p + e.totalCost);
    final totalDistance =
        filtered.fold<double>(0, (p, e) => p + e.distanceKm);

    final avgCostPerKm =
        totalDistance > 0 ? totalCost / totalDistance : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                child: Text('Hafta'),
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
                                groupedCosts[labels[i]] ?? 0,
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
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= labels.length) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  labels[index],
                                  style: const TextStyle(fontSize: 9),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatCardMini(
                  title: 'Jami xarajat',
                  value:
                      '${NumberFormat("#,##0").format(totalCost)} so‘m',
                  icon: Icons.payments,
                ),
              ),
              const SizedBox(width: 12),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
