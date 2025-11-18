import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/models.dart';
import '../core/storage.dart';


class AiAutoScreen extends StatelessWidget {
  final Box box;
  final AppProfile profile;
  const AiAutoScreen({super.key, required this.box, required this.profile});

  @override
  Widget build(BuildContext context) {
    final entries = loadEntries(box);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    double? avgLPer100;
    double? avgKmPerLiter;
    double? estimatedRange;

    if (entries.isNotEmpty) {
      final consList =
          entries.map((e) => e.consumptionPer100).whereType<double>().toList();
      if (consList.isNotEmpty) {
        avgLPer100 = consList.reduce((a, b) => a + b) / consList.length;
        avgKmPerLiter = 100 / avgLPer100;
      }

      if (avgKmPerLiter != null && profile.gasTankCapacity != null) {
        estimatedRange = profile.gasTankCapacity! * avgKmPerLiter;
      }
    }

    final totalCost =
        entries.fold<double>(0, (p, e) => p + e.totalCost);
    final totalDistance =
        entries.fold<double>(0, (p, e) => p + e.distanceKm);

    final avgCostPerKm =
        totalDistance > 0 ? totalCost / totalDistance : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Auto tavsiyalar',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Oldingi ma’lumotlarga tayangan holda keyingi yoqilg‘i va yurish masofasi bo‘yicha qisqacha tahlil.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                    : [const Color(0xFF1D4ED8), const Color(0xFF22C55E)],
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    estimatedRange == null
                        ? 'Hali yetarlicha ma’lumot yo‘q.\nBir necha marotaba yoqilg‘i yozuvi kiritgandan keyin taxminiy yo‘l masofasini ko‘rsatamiz.'
                        : 'Hozirgi o‘rtacha sarf bo‘yicha balon to‘liq to‘lganda taxminan ${estimatedRange.toStringAsFixed(0)} km yuradi.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatCardLike(
                  title: 'O‘rtacha sarf',
                  value: avgLPer100 == null
                      ? '—'
                      : '${avgLPer100.toStringAsFixed(1)} L/100km',
                  icon: Icons.speed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCardLike(
                  title: '1 km narxi',
                  value: avgCostPerKm == null
                      ? '—'
                      : '${avgCostPerKm.toStringAsFixed(0)} so‘m',
                  icon: Icons.payments,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isNotEmpty)
            _AiAdviceList(
              avgLPer100: avgLPer100,
              avgCostPerKm: avgCostPerKm,
              estimatedRange: estimatedRange,
            ),
        ],
      ),
    );
  }
}

class _StatCardLike extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCardLike({
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

class _AiAdviceList extends StatelessWidget {
  final double? avgLPer100;
  final double? avgCostPerKm;
  final double? estimatedRange;

  const _AiAdviceList({
    this.avgLPer100,
    this.avgCostPerKm,
    this.estimatedRange,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> advices = [];

    if (avgLPer100 != null) {
      if (avgLPer100! > 12) {
        advices.add(
            'Yoqilg‘i sarfi biroz balandroq. Tez-tez keskin gaz berishdan qoching va shahar tashqarisida o‘rtacha tezlikda yuring.');
      } else if (avgLPer100! < 8) {
        advices.add(
            'Ajoyib! Avtomobil juda iqtisodiy ishlayapti. Hozirgi uslubni davom ettiring.');
      } else {
        advices.add(
            'Sarf o‘rtacha. Agar yanada tejamkor bo‘lishni istasangiz, keraksiz holatda dvigatelni ishlatib qo‘ymang.');
      }
    }

    if (avgCostPerKm != null) {
      advices.add(
          'Hozircha 1 km uchun o‘rtacha ${avgCostPerKm!.toStringAsFixed(0)} so‘m sarflayapsiz. Keyingi yoqilg‘i narxiga qarab bu qiymat o‘zgaradi.');
    }

    if (estimatedRange != null) {
      advices.add(
          'To‘liq balon bilan taxminan ${estimatedRange!.toStringAsFixed(0)} km yurish mumkin – yo‘lni rejalashtirganda e’tiborga oling.');
    }

    if (advices.isEmpty) {
      advices.add(
          'Hozircha AI tavsiyalar uchun ma’lumot yetarli emas. Bir necha marta yoqilg‘i yozuvlari kiriting.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Qisqacha tavsiyalar',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...advices.map(
          (a) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceVariant
                  .withOpacity(0.4),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates,
                    size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a,
                    style: const TextStyle(fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}
