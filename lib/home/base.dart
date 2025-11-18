import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../ai/render.dart';
import '../core/models.dart';
import '../core/storage.dart';
import '../setting/config.dart';
import '../stat/statistic.dart';

class OnboardingScreen extends StatefulWidget {
  final Box box;
  const OnboardingScreen({super.key, required this.box});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _customCarCtrl = TextEditingController();

  FuelType _fuelType = FuelType.petrolLpg;
  String _selectedCar = 'Chevrolet Nexia 3';
  double? _tankCapacity;

  final List<String> _uzbekCarModels = [
    'Chevrolet Nexia 3',
    'Chevrolet Cobalt',
    'Chevrolet Gentra',
    'Chevrolet Malibu 1',
    'Chevrolet Malibu 2',
    'Chevrolet Spark',
    'Chevrolet Damas',
    'Chevrolet Lacetti',
    'Chevrolet Orlando',
    'Chevrolet Tracker',
    'Chevrolet Onix',
    'Chevrolet Equinox',
    'Chevrolet Tahoe',
    'Boshqa (o‘zim kiritaman)',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _plateCtrl.dispose();
    _customCarCtrl.dispose();
    super.dispose();
  }

  String get _finalCarModel {
    if (_selectedCar == 'Boshqa (o‘zim kiritaman)') {
      return _customCarCtrl.text.trim().isEmpty
          ? 'Mening avtomobilim'
          : _customCarCtrl.text.trim();
    }
    return _selectedCar;
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    final profile = AppProfile(
      id: 'profile_1',
      name:
          _nameCtrl.text.trim().isEmpty ? 'Haydovchi' : _nameCtrl.text.trim(),
      carModel: _finalCarModel,
      fuelType: _fuelType,
      plateNumber:
          _plateCtrl.text.trim().isEmpty ? null : _plateCtrl.text.trim(),
      gasTankCapacity: _tankCapacity,
    );

    widget.box.put('profile', profile.toMap());
    widget.box.put('themeMode', 'system');

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MainShell(box: widget.box)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 40 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'AutoXarajat',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Avtomobil yoqilg‘i xarajatlarini aqlli boshqarish',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF0F172A),
                            const Color(0xFF1E293B),
                          ]
                        : [
                            const Color(0xFF2563EB),
                            const Color(0xFF22C55E),
                          ],
                  ),
                ),
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car_filled_rounded,
                        size: 42, color: Colors.white),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Boshlashdan oldin profil va avtomobil ma’lumotlarini kiriting. Keyin hamma hisob-kitoblarni biz qilib beramiz.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Foydalanuvchi ma’lumotlari',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ism (ixtiyoriy)',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _plateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Davlat raqami (ixtiyoriy)',
                        prefixIcon: Icon(Icons.credit_card),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Avtomobil', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedCar,
                      items: _uzbekCarModels
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(m),
                            ),
                          )
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        prefixIcon: Icon(Icons.directions_car),
                      ),
                      onChanged: (v) {
                        setState(() {
                          _selectedCar = v ?? _selectedCar;
                        });
                      },
                    ),
                    if (_selectedCar == 'Boshqa (o‘zim kiritaman)') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customCarCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Avtomobil nomi',
                          prefixIcon: Icon(Icons.edit),
                        ),
                        validator: (v) {
                          if (_selectedCar ==
                                  'Boshqa (o‘zim kiritaman)' &&
                              (v == null || v.trim().isEmpty)) {
                            return 'Avtomobil nomini kiriting';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text('Yoqilg‘i turi', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        RadioListTile<FuelType>(
                          value: FuelType.petrol,
                          groupValue: _fuelType,
                          title: const Text('Faqat benzin'),
                          onChanged: (v) {
                            setState(() {
                              _fuelType = v!;
                            });
                          },
                        ),
                        RadioListTile<FuelType>(
                          value: FuelType.petrolLpg,
                          groupValue: _fuelType,
                          title: const Text('Benzin + Propan (LPG)'),
                          onChanged: (v) {
                            setState(() {
                              _fuelType = v!;
                            });
                          },
                        ),
                        RadioListTile<FuelType>(
                          value: FuelType.petrolCng,
                          groupValue: _fuelType,
                          title: const Text('Benzin + Metan (CNG)'),
                          onChanged: (v) {
                            setState(() {
                              _fuelType = v!;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_fuelType != FuelType.petrol)
                      TextFormField(
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: _fuelType == FuelType.petrolLpg
                              ? 'Propan balon hajmi (litr)'
                              : 'Metan balon hajmi (m³ taxminiy)',
                          prefixIcon: const Icon(Icons.local_gas_station),
                        ),
                        validator: (v) {
                          if (_fuelType == FuelType.petrol) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Balon hajmini kiriting';
                          }
                          final parsed = double.tryParse(
                              v.replaceAll(',', '.').trim());
                          if (parsed == null || parsed <= 0) {
                            return 'To‘g‘ri son kiriting';
                          }
                          return null;
                        },
                        onChanged: (v) {
                          final parsed =
                              double.tryParse(v.replaceAll(',', '.').trim());
                          setState(() {
                            _tankCapacity = parsed;
                          });
                        },
                      ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saveProfile,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Boshlash',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

/// —————————————————
/// MAIN SHELL
/// —————————————————

class MainShell extends StatefulWidget {
  final Box box;
  const MainShell({super.key, required this.box});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final profileMap = widget.box.get('profile') as Map<dynamic, dynamic>?;
    if (profileMap == null) {
      return OnboardingScreen(box: widget.box);
    }
    final profile = AppProfile.fromMap(profileMap);

    final pages = [
      DashboardScreen(box: widget.box, profile: profile),
      AiAutoScreen(box: widget.box, profile: profile),
      StatsScreen(box: widget.box, profile: profile),
      SettingsScreen(box: widget.box, profile: profile),
    ];

    final titles = [
      'Asosiy',
      'AI Auto',
      'Statistika',
      'Sozlamalar',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Asosiy',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI Auto',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stat',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Sozlama',
          ),
        ],
      ),
    );
  }
}

/// —————————————————
/// DASHBOARD SCREEN
/// —————————————————

class DashboardScreen extends StatefulWidget {
  final Box box;
  final AppProfile profile;
  const DashboardScreen({super.key, required this.box, required this.profile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<RefuelEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = tryLoadFromICloud(widget.box);
  }

  void _refresh() {
    setState(() {
      _future = tryLoadFromICloud(widget.box);
    });
  }

  void _openAddEntrySheet({RefuelEntry? existing}) async {
    final result = await showModalBottomSheet<RefuelEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddEntrySheet(existing: existing),
    );

    if (result != null) {
      final entries = loadEntries(widget.box);
      final updatedList = [
        ...entries.where((e) => e.id != result.id),
        result,
      ]..sort((a, b) => a.date.compareTo(b.date));

      await saveEntries(widget.box, updatedList);
      _refresh();
    }
  }

  Future<void> _deleteEntry(RefuelEntry entry) async {
    final entries =
        loadEntries(widget.box).where((e) => e.id != entry.id).toList();
    await saveEntries(widget.box, entries);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<List<RefuelEntry>>(
      future: _future,
      builder: (context, snap) {
        final entries = snap.data ?? [];
        final totalDistance =
            entries.fold<double>(0, (p, e) => p + e.distanceKm);
        final totalLiters = entries.fold<double>(0, (p, e) => p + e.liters);
        final totalCost = entries.fold<double>(0, (p, e) => p + e.totalCost);

        final avgConsumption = entries
            .map((e) => e.consumptionPer100)
            .whereType<double>()
            .toList();
        final avgCons = avgConsumption.isEmpty
            ? null
            : avgConsumption.reduce((a, b) => a + b) / avgConsumption.length;

        return Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _HeaderCard(profile: widget.profile),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Jami yo‘l',
                      value: '${totalDistance.toStringAsFixed(0)} km',
                      icon: Icons.route,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Jami yoqilg‘i',
                      value: '${totalLiters.toStringAsFixed(1)} L',
                      icon: Icons.local_gas_station,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Jami xarajat',
                      value:
                          '${NumberFormat("#,##0").format(totalCost)} so‘m',
                      icon: Icons.payments,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'O‘rtacha sarf',
                      value: avgCons == null
                          ? '—'
                          : '${avgCons.toStringAsFixed(1)} L / 100 km',
                      icon: Icons.speed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: isDark ? const Color(0xFF020617) : Colors.white,
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          )
                        ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Row(
                        children: [
                          const Text(
                            'Yoqilg‘i yozuvlari',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _openAddEntrySheet(),
                            icon: const Icon(Icons.add_rounded),
                            tooltip: 'Yangi yozuv',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: entries.isEmpty
                          ? const Center(
                              child: Text(
                                'Hozircha yozuvlar yo‘q.\nPastdagi + tugmasi orqali qo‘shing.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 16),
                              itemBuilder: (_, i) {
                                final e = entries[entries.length - 1 - i];
                                return _EntryTile(
                                  entry: e,
                                  onEdit: () =>
                                      _openAddEntrySheet(existing: e),
                                  onDelete: () => _deleteEntry(e),
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemCount: entries.length,
                            ),
                    ),
                  ],
                ),
              ),
            )
          ],
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final AppProfile profile;
  const _HeaderCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fuelText = switch (profile.fuelType) {
      FuelType.petrol => 'Benzin',
      FuelType.petrolLpg => 'Benzin + Propan',
      FuelType.petrolCng => 'Benzin + Metan',
    };

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF2563EB), const Color(0xFF22C55E)],
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withOpacity(0.15),
            ),
            child: const Icon(Icons.directions_car_filled_rounded,
                color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.carModel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.plateNumber ?? 'Davlat raqami kiritilmagan',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fuelText +
                      (profile.gasTankCapacity != null
                          ? ' • Balon: ${profile.gasTankCapacity!.toStringAsFixed(1)}'
                          : ''),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
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

class _EntryTile extends StatelessWidget {
  final RefuelEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    final cons = entry.consumptionPer100;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade500,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.orange.withOpacity(0.16),
                ),
                child: const Icon(Icons.local_gas_station_rounded,
                    color: Colors.orange),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(df.format(entry.date),
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.distanceKm.toStringAsFixed(0)} km • '
                      '${entry.liters.toStringAsFixed(1)} L • '
                      '${NumberFormat("#,##0").format(entry.totalCost)} so‘m',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (entry.isFullTank)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Full',
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    cons == null
                        ? '—'
                        : '${cons.toStringAsFixed(1)} L/100km',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class AddEntrySheet extends StatefulWidget {
  final RefuelEntry? existing;
  const AddEntrySheet({super.key, this.existing});

  @override
  State<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<AddEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _distanceCtrl = TextEditingController();
  final _litersCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _isFull = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _distanceCtrl.text = e.distanceKm.toStringAsFixed(0);
      _litersCtrl.text = e.liters.toStringAsFixed(1);
      _priceCtrl.text = e.pricePerLiter.toStringAsFixed(0);
      _date = e.date;
      _isFull = e.isFullTank;
    }
  }

  @override
  void dispose() {
    _distanceCtrl.dispose();
    _litersCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final distance =
        double.parse(_distanceCtrl.text.replaceAll(',', '.').trim());
    final liters =
        double.parse(_litersCtrl.text.replaceAll(',', '.').trim());
    final price =
        double.parse(_priceCtrl.text.replaceAll(',', '.').trim());

    final entry = RefuelEntry(
      id: widget.existing?.id ??
          'entry_${DateTime.now().millisecondsSinceEpoch}',
      date: _date,
      distanceKm: distance,
      liters: liters,
      pricePerLiter: price,
      isFullTank: _isFull,
    );

    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.grey.withOpacity(0.4),
                ),
              ),
              Text(
                widget.existing == null
                    ? 'Yangi yoqilg‘i yozuvi'
                    : 'Yozuvni tahrirlash',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _distanceCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Yurgan masofa (km)',
                              prefixIcon: Icon(Icons.route),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Masofani kiriting';
                              }
                              final d = double.tryParse(
                                  v.replaceAll(',', '.').trim());
                              if (d == null || d <= 0) {
                                return 'To‘g‘ri km kiriting';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _litersCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Quyilgan litr',
                              prefixIcon: Icon(Icons.local_gas_station),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Litrni kiriting';
                              }
                              final d = double.tryParse(
                                  v.replaceAll(',', '.').trim());
                              if (d == null || d <= 0) {
                                return 'To‘g‘ri litr kiriting';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: '1 litr narxi (so‘m)',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Narxni kiriting';
                              }
                              final d = double.tryParse(
                                  v.replaceAll(',', '.').trim());
                              if (d == null || d <= 0) {
                                return 'To‘g‘ri narx kiriting';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _date,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setState(() {
                                  _date = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Sana',
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(df.format(_date)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _isFull,
                      title: const Text('Full quyildi'),
                      subtitle: const Text(
                        'Agar balon to‘liq to‘ldirilgan bo‘lsa, yoqing – statistikada aniqroq hisob bo‘ladi.',
                      ),
                      onChanged: (v) {
                        setState(() {
                          _isFull = v;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _save,
                        child: Text(
                          widget.existing == null
                              ? 'Saqlash'
                              : 'O‘zgartirish',
                        ),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
