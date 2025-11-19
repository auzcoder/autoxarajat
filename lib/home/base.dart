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
  String _selectedCar = 'Chevrolet Cobalt';

  final List<String> _uzbekCarModels = const [
    'Chevrolet Cobalt',
    'Chevrolet Nexia 3',
    'Chevrolet Lacetti (Gentra)',
    'Chevrolet Spark',
    'Chevrolet Malibu',
    'Chevrolet Tracker',
    'Damas',
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
      if (_customCarCtrl.text.trim().isEmpty) {
        return 'Mening avtomobilim';
      }
      return _customCarCtrl.text.trim();
    }
    return _selectedCar;
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    final profile = AppProfile(
      id: 'profile_1',
      name: _nameCtrl.text.trim().isEmpty
          ? 'Haydovchi'
          : _nameCtrl.text.trim(),
      carModel: _finalCarModel,
      fuelType: _fuelType,
      plateNumber: _plateCtrl.text.trim(),
      gasTankCapacity: null,
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
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AutoXarajatga xush kelibsiz 👋',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Avtomobil bo‘yicha sarf-xarajatlaringizni premium UI bilan tartibli yuritamiz.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: isDark
                            ? const Color(0xFF020617)
                            : Colors.white,
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color:
                                      Colors.black.withOpacity(0.05),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                )
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Haydovchi',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
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
                              labelText: 'Davlat raqam',
                              prefixIcon:
                                  Icon(Icons.directions_car_filled),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Davlat raqamini kiriting';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: isDark
                            ? const Color(0xFF020617)
                            : Colors.white,
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color:
                                      Colors.black.withOpacity(0.05),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                )
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Avtomobil',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
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
                              prefixIcon:
                                  Icon(Icons.directions_car_rounded),
                            ),
                            onChanged: (v) {
                              setState(() {
                                _selectedCar = v ?? _selectedCar;
                              });
                            },
                          ),
                          if (_selectedCar ==
                              'Boshqa (o‘zim kiritaman)') ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _customCarCtrl,
                              decoration: const InputDecoration(
                                labelText:
                                    'Model nomini o‘zingiz kiriting',
                              ),
                              validator: (v) {
                                if (_selectedCar ==
                                        'Boshqa (o‘zim kiritaman)' &&
                                    (v == null ||
                                        v.trim().isEmpty)) {
                                  return 'Avtomobil nomini kiriting';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text('Yoqilg‘i turi',
                              style: theme.textTheme.titleMedium),
                          Column(
                            children: [
                              RadioListTile<FuelType>(
                                value: FuelType.petrol,
                                groupValue: _fuelType,
                                title:
                                    const Text('Faqat benzin'),
                                onChanged: (v) {
                                  setState(() {
                                    _fuelType = v!;
                                  });
                                },
                              ),
                              RadioListTile<FuelType>(
                                value: FuelType.petrolLpg,
                                groupValue: _fuelType,
                                title: const Text(
                                    'Benzin + Propan (LPG)'),
                                onChanged: (v) {
                                  setState(() {
                                    _fuelType = v!;
                                  });
                                },
                              ),
                              RadioListTile<FuelType>(
                                value: FuelType.petrolCng,
                                groupValue: _fuelType,
                                title: const Text(
                                    'Benzin + Metan (CNG)'),
                                onChanged: (v) {
                                  setState(() {
                                    _fuelType = v!;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saveProfile,
                        child: const Text('Boshlash'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// MAIN SHELL

class MainShell extends StatefulWidget {
  final Box box;
  const MainShell({super.key, required this.box});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  Future<void> _openQuickAddEntry() async {
    final profileMap = widget.box.get('profile') as Map<dynamic, dynamic>?;
    if (profileMap == null) return;
    final profile = AppProfile.fromMap(profileMap);

    final result = await showModalBottomSheet<RefuelEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddEntrySheet(profile: profile),
    );

    if (result != null) {
      final entries = loadEntries(widget.box);
      final updatedList = [
        ...entries.where((e) => e.id != result.id),
        result,
      ]..sort((a, b) => a.date.compareTo(b.date));

      await saveEntries(widget.box, updatedList);
      setState(() {});
    }
  }

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

    final titles = ['Asosiy', 'AI Auto', 'Statistika', 'Sozlamalar'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<int>(_index),
          child: pages[_index],
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _openQuickAddEntry,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        elevation: 6,
        child: const Icon(
          Icons.add_rounded,
          size: 30,
        ),
      ),
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

/// DASHBOARD

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
      builder: (_) => AddEntrySheet(
        existing: existing,
        profile: widget.profile,
      ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<List<RefuelEntry>>(
      future: _future,
      builder: (context, snap) {
        final allEntries = snap.data ?? [];
        final entries = _filterByProfilePlate(allEntries);

        final totalDistance =
            entries.fold<double>(0, (p, e) => p + e.distanceKm);
        final totalLiters =
            entries.fold<double>(0, (p, e) => p + e.liters);
        final totalCost =
            entries.fold<double>(0, (p, e) => p + e.totalCost);

        final consList = entries
            .map((e) => e.consumptionPer100)
            .whereType<double>()
            .toList();
        final avgCons = consList.isEmpty
            ? null
            : consList.reduce((a, b) => a + b) / consList.length;

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
                      icon: Icons.local_gas_station_rounded,
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
                      value: '${totalCost.toStringAsFixed(0)} so‘m',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'O‘rtacha sarf',
                      value: avgCons == null
                          ? '—'
                          : '${avgCons.toStringAsFixed(1)} L/100km',
                      icon: Icons.speed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                                'Bu avtomobil uchun hozircha ma’lumot yo‘q.\nAvval birinchi yoqilg‘i yozuvini qo‘shing.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  8, 8, 8, 16),
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
                                final e = entries[index];
                                return _EntryTile(
                                  entry: e,
                                  onEdit: () =>
                                      _openAddEntrySheet(existing: e),
                                  onDelete: () => _deleteEntry(e),
                                  isDark: isDark,
                                );
                              },
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF0B1120),
                  const Color(0xFF1E293B),
                ]
              : [
                  const Color(0xFF2563EB),
                  const Color(0xFF38BDF8),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withOpacity(0.1),
            child: Text(
              (profile.name.isNotEmpty ? profile.name[0] : 'A')
                  .toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.carModel,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (profile.plateNumber != null &&
              profile.plateNumber!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.15),
              ),
              child: Text(
                profile.plateNumber!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final RefuelEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDark;

  const _EntryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    final cons = entry.consumptionPer100;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? const Color(0xFF020617) : Colors.white,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFE0F2FE),
                ),
                child: const Icon(Icons.local_gas_station_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.liters.toStringAsFixed(1)} L · ${entry.distanceKm.toStringAsFixed(0)} km',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      df.format(entry.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(0.7),
                          ),
                    ),
                    if (cons != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${cons.toStringAsFixed(1)} L/100km',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.8),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.totalCost.toStringAsFixed(0)} so‘m',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: entry.isFullTank
                              ? Colors.green.withOpacity(0.08)
                              : Colors.orange.withOpacity(0.08),
                        ),
                        child: Text(
                          entry.isFullTank
                              ? 'To‘la quyildi'
                              : 'Qisman quyildi',
                          style: TextStyle(
                            color: entry.isFullTank
                                ? Colors.green
                                : Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                        ),
                      ),
                    ],
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

/// QO‘SHISH SHEET

class AddEntrySheet extends StatefulWidget {
  final RefuelEntry? existing;
  final AppProfile profile;
  const AddEntrySheet({super.key, this.existing, required this.profile});

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

  void _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (result != null) {
      setState(() {
        _date = result;
      });
    }
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
      plateNumber:
          widget.existing?.plateNumber ?? widget.profile.plateNumber,
    );

    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
        child: Form(
          key: _formKey,
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _distanceCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Masofa (km)',
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
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _litersCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Litr (L)',
                    prefixIcon: Icon(Icons.local_gas_station_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Litrni kiriting';
                    }
                    final d =
                        double.tryParse(v.replaceAll(',', '.').trim());
                    if (d == null || d <= 0) {
                      return 'To‘g‘ri litr kiriting';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Narx (1 L uchun, so‘m)',
                    prefixIcon: Icon(Icons.price_change),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Narxni kiriting';
                    }
                    final d =
                        double.tryParse(v.replaceAll(',', '.').trim());
                    if (d == null || d <= 0) {
                      return 'To‘g‘ri narx kiriting';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sana: ${df.format(_date)}',
                      ),
                    ),
                    TextButton(
                      onPressed: _pickDate,
                      child: const Text('Sana tanlash'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _isFull,
                  title: Text(
                      _isFull ? 'To‘la quyildi' : 'Qisman quyildi'),
                  subtitle: const Text(
                    'Balon to‘liq to‘ldirilgan bo‘lsa "To‘la", aks holda "Qisman" – statistikada to‘g‘ri hisoblash uchun.',
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
