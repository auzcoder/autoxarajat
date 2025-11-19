import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/models.dart';
import '../core/storage.dart';

class AiAutoScreen extends StatelessWidget {
  final Box box;
  final AppProfile profile;
  const AiAutoScreen({super.key, required this.box, required this.profile});

  List<RefuelEntry> _filterByProfilePlate(List<RefuelEntry> entries) {
    final plate = profile.plateNumber;
    if (plate == null || plate.isEmpty) {
      return entries
          .where((e) => e.plateNumber == null || e.plateNumber!.isEmpty)
          .toList();
    }
    return entries.where((e) => e.plateNumber == plate).toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = loadEntries(box);
    final entries = _filterByProfilePlate(all);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    double? avgLPer100;
    double? avgKmPerLiter;
    double? estimatedRange;
    double? minRange;
    double? maxRange;

    if (entries.isNotEmpty) {
      // Faqat TO‘LIQ quyilgan yozuvlar bo‘yicha hisoblaymiz (aniqroq bo‘lsin)
      final fullEntries = entries
          .where((e) => e.isFullTank && e.consumptionPer100 != null)
          .toList();
      final usedList = fullEntries.isNotEmpty ? fullEntries : entries;

      final consList = usedList
          .map((e) => e.consumptionPer100)
          .whereType<double>()
          .toList();

      if (consList.isNotEmpty) {
        consList.sort();
        // Oxirgi 3 ta qiymat bo‘yicha (yangi ma’lumotlar asosida) o‘rtacha
        final last3 = consList.length <= 3
            ? consList
            : consList.sublist(consList.length - 3);
        avgLPer100 =
            last3.reduce((a, b) => a + b) / last3.length;

        avgKmPerLiter = 100 / avgLPer100;

        if (profile.gasTankCapacity != null) {
          final base = profile.gasTankCapacity! * avgKmPerLiter;
          // Ozroq diapazon beramiz (±7%)
          estimatedRange = base;
          minRange = base * 0.93;
          maxRange = base * 1.07;
        }
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
            'So‘nggi yoqilg‘i ma’lumotlari asosida sarf, 1 km narxi va keyingi safar qaysi km atrofida yoqilg‘i tugashini taxmin qilamiz.',
            style: theme.textTheme.bodySmall?.copyWith(
              color:
                  theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 18),
          if (estimatedRange != null)
            _RangeHighlightCard(
              estimatedRange: estimatedRange!,
              minRange: minRange,
              maxRange: maxRange,
            ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF1E293B),
                        const Color(0xFF0F172A),
                      ]
                    : [
                        const Color(0xFF2563EB),
                        const Color(0xFF22C1C3),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
                        ? 'Hali yetarlicha ma’lumot yo‘q.\nBir necha to‘liq yoqilg‘i yozuvlari kiritgandan keyin keyingi safar qaysi kmda yoqilg‘i tugashini aniqroq taxmin qilib beramiz.'
                        : 'So‘nggi to‘liq yoqilg‘i ma’lumotlariga asoslangan taxmin. Real sarf uslubingizga qarab ±10% atrofida farq qilishi mumkin.',
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
              const SizedBox(width: 10),
              Expanded(
                child: _StatCardLike(
                  title: '1 km narxi',
                  value: avgCostPerKm == null
                      ? '—'
                      : '${avgCostPerKm.toStringAsFixed(0)} so‘m',
                  icon: Icons.price_change,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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

class _RangeHighlightCard extends StatelessWidget {
  final double estimatedRange;
  final double? minRange;
  final double? maxRange;
  const _RangeHighlightCard({
    super.key,
    required this.estimatedRange,
    this.minRange,
    this.maxRange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String subtitle;
    if (minRange != null && maxRange != null) {
      subtitle =
          'Taxminiy diapazon: ${minRange!.toStringAsFixed(0)} – ${maxRange!.toStringAsFixed(0)} km.\n'
          'Yoqilg‘i tugashiga yaqinlashganda bu oraliqda bo‘lishi mumkin.';
    } else {
      subtitle =
          'Taxminan shu masofadan so‘ng bakdagi yoqilg‘i tugaydi. Safarlaringizni shu bo‘yicha rejalashtiring.';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.15),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keyingi yoqilg‘i rejasi',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0, end: estimatedRange),
            builder: (context, value, _) {
              return Text(
                '${value.toStringAsFixed(0)} km',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
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
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.blueGrey.shade900
                  : Colors.blue.shade50,
            ),
            child: Icon(
              icon,
              size: 18,
              color: theme.colorScheme.primary,
            ),
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
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
          'Yoqilg‘i sarfi biroz baland. Gaz pedalini keskin bosmaslik, '
          'tez-tez to‘xtash–yurishlardan qochish yoqilg‘i sarfini sezilarli kamaytiradi.',
        );
      } else if (avgLPer100! < 8) {
        advices.add(
          'Ajoyib! Avtomobil juda iqtisodiy ishlayapti. Hozirgi haydash uslubini davom ettiring.',
        );
      } else {
        advices.add(
          'Sarf normal diapazonda. Agar yana tejamoqchi bo‘lsangiz, '
          'shahar tirband vaqtlarida kamroq harakatlanishga harakat qiling.',
        );
      }
    }

    if (avgCostPerKm != null) {
      advices.add(
        'Hozircha 1 km yo‘l sizga taxminan ${avgCostPerKm!.toStringAsFixed(0)} so‘mga tushmoqda.',
      );
    }

    if (estimatedRange != null) {
      advices.add(
        'Bak to‘la bo‘lganda taxminiy yurish masofasi ${estimatedRange!.toStringAsFixed(0)} km atrofida.',
      );
    }

    if (advices.isEmpty) {
      advices.add(
        'Hozircha AI tavsiyalar uchun ma’lumot yetarli emas. Bir necha marta yoqilg‘i yozuvlari kiriting.',
      );
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
              color: Theme.of(context).colorScheme.surfaceVariant
                  .withOpacity(0.4),
            ),
            child: Text(
              a,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}
