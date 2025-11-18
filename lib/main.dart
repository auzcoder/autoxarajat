import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

/// —————————————————————————
/// MODELLAR VA ENUM’LAR
/// —————————————————————————

enum FuelType {
  petrol,
  petrolLpg,
  petrolCng,
}

class AppProfile {
  final String id;
  final String name;
  final String? plateNumber;
  final String carModel;
  final FuelType fuelType;
  final double? gasTankCapacity; // LPG: litr, CNG: m3

  AppProfile({
    required this.id,
    required this.name,
    required this.carModel,
    required this.fuelType,
    this.plateNumber,
    this.gasTankCapacity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'plateNumber': plateNumber,
      'carModel': carModel,
      'fuelType': fuelType.index,
      'gasTankCapacity': gasTankCapacity,
    };
  }

  factory AppProfile.fromMap(Map<dynamic, dynamic> map) {
    return AppProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      plateNumber: map['plateNumber'] as String?,
      carModel: map['carModel'] as String,
      fuelType: FuelType.values[(map['fuelType'] ?? 0) as int],
      gasTankCapacity: (map['gasTankCapacity'] as num?)?.toDouble(),
    );
  }
}

class RefuelEntry {
  final String id;
  final DateTime date;
  final double distanceKm; // shu yoqilg‘ida yurgan km
  final double liters; // quyilgan litr
  final double pricePerLiter; // so‘m
  final bool isFullTank;

  RefuelEntry({
    required this.id,
    required this.date,
    required this.distanceKm,
    required this.liters,
    required this.pricePerLiter,
    required this.isFullTank,
  });

  double get totalCost => liters * pricePerLiter;

  /// 100 km ga sarf (l/100km)
  double? get consumptionPer100 {
    if (distanceKm <= 0 || liters <= 0) return null;
    return (liters / distanceKm) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'distanceKm': distanceKm,
      'liters': liters,
      'pricePerLiter': pricePerLiter,
      'isFullTank': isFullTank,
    };
  }

  factory RefuelEntry.fromMap(Map<dynamic, dynamic> map) {
    return RefuelEntry(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      distanceKm: (map['distanceKm'] as num).toDouble(),
      liters: (map['liters'] as num).toDouble(),
      pricePerLiter: (map['pricePerLiter'] as num).toDouble(),
      isFullTank: map['isFullTank'] as bool? ?? false,
    );
  }
}

/// —————————————————————————
/// KIRISH NUQTASI
/// —————————————————————————

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox('autox_box');

  runApp(AutoXApp(box: box));
}

/// —————————————————————————
/// ASOSIY APP (Theme + Lock + Onboarding)
/// —————————————————————————

class AutoXApp extends StatelessWidget {
  final Box box;
  const AutoXApp({super.key, required this.box});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box<dynamic> box, _) {
        final themeString = box.get('themeMode', defaultValue: 'system') as String;
        final themeMode = switch (themeString) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };

        // PIN lock bor-yo‘qligini tekshiramiz
        final hasPin = (box.get('lockPin') as String?)?.isNotEmpty == true;
        final lockEnabled = box.get('lockEnabled', defaultValue: false) as bool;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'AutoXarajat',
          themeMode: themeMode,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          home: hasPin && lockEnabled
              ? LockScreen(box: box)
              : _buildStartScreen(box),
        );
      },
    );
  }

  Widget _buildStartScreen(Box box) {
    final profileMap = box.get('profile') as Map<dynamic, dynamic>?;
    if (profileMap == null) {
      return OnboardingScreen(box: box);
    }
    return MainShell(box: box);
  }
}

/// —————————————————————————
/// THEME’LAR
/// —————————————————————————

ThemeData _buildLightTheme() {
  const primary = Color(0xFF2563EB);
  const surface = Color(0xFFF9FAFB);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: primary,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
    ),
  );
}

ThemeData _buildDarkTheme() {
  const primary = Color(0xFF60A5FA);
  const surface = Color(0xFF020617);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: primary,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
    ),
  );
}

/// —————————————————————————
/// ONBOARDING – PROFIL + MASHINA + YOQILG‘I
/// —————————————————————————

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
      return _customCarCtrl.text.trim().isEmpty ? 'Mening avtomobilim' : _customCarCtrl.text.trim();
    }
    return _selectedCar;
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    final profile = AppProfile(
      id: 'profile_1',
      name: _nameCtrl.text.trim().isEmpty ? 'Haydovchi' : _nameCtrl.text.trim(),
      carModel: _finalCarModel,
      fuelType: _fuelType,
      plateNumber: _plateCtrl.text.trim().isEmpty ? null : _plateCtrl.text.trim(),
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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
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
                    Expanded(
                      child: Text(
                        'Boshlashdan oldin profil va avtomobil ma’lumotlarini kiriting. Keyin hamma hisob-kitoblarni biz qilib beramiz.',
                        style: const TextStyle(
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

/// —————————————————————————
/// ASOSIY SHELL – BOTTOM NAV (Home, AI Auto, Stats, Settings)
/// —————————————————————————

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
      // Agar profil yo‘q bo‘lsa, onboardingga qaytamiz
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

/// —————————————————————————
/// HIVE + ICLOUD – YORDAMCHI FUNKSIYALAR
/// —————————————————————————

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

/// —————————————————————————
/// ASOSIY – DASHBOARD (kiritish + qisqa statistika)
/// —————————————————————————

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
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddEntrySheet(existing: existing),
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
                  color: isDark
                      ? const Color(0xFF020617)
                      : Colors.white,
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

/// —————————————————————————
/// UI WIDGETLAR: Header, StatCard, EntryTile, AddEntrySheet
/// —————————————————————————

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
                      '${entry.distanceKm.toStringAsFixed(0)} km • ${entry.liters.toStringAsFixed(1)} L • ${NumberFormat("#,##0").format(entry.totalCost)} so‘m',
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
      id: widget.existing?.id ?? 'entry_${DateTime.now().millisecondsSinceEpoch}',
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                        keyboardType: const TextInputType.numberWithOptions(
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
                        keyboardType: const TextInputType.numberWithOptions(
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
                        keyboardType: const TextInputType.numberWithOptions(
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
                    child: Text(widget.existing == null
                        ? 'Saqlash'
                        : 'O‘zgartirish'),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

/// —————————————————————————
/// AI AUTO – "AI" ko‘rinishidagi aqlli statistikalar
/// —————————————————————————

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
      final consList = entries
          .map((e) => e.consumptionPer100)
          .whereType<double>()
          .toList();
      if (consList.isNotEmpty) {
        avgLPer100 =
            consList.reduce((a, b) => a + b) / consList.length;
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

    final avgCostPerKm = totalDistance > 0
        ? totalCost / totalDistance
        : null;

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
                child: _StatCard(
                  title: 'O‘rtacha sarf',
                  value: avgLPer100 == null
                      ? '—'
                      : '${avgLPer100.toStringAsFixed(1)} L/100km',
                  icon: Icons.speed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
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

/// —————————————————————————
/// STATISTIKA – chartlar (haftalik / oylik / yillik)
/// —————————————————————————

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

    // Haftalik / oylik / yillik bo‘yicha filtr
    bool inRange(DateTime d) {
      final diff = now.difference(DateTime(d.year, d.month, d.day)).inDays;
      switch (_range) {
        case StatsRange.week:
          return diff <= 7;
        case StatsRange.month:
          return diff <= 31;
        case StatsRange.year:
          return diff <= 365;
      }
    }

    final filtered =
        entries.where((e) => inRange(e.date)).toList();

    // Chart uchun: vaqt bo‘yicha guruhlangan jami xarajat
    final Map<String, double> groupedCosts = {};

    for (final e in filtered) {
      late String key;
      switch (_range) {
        case StatsRange.week:
          key = DateFormat('dd.MM').format(e.date);
          break;
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
      ..sort((a, b) {
        // Ko‘rinish tartibi
        return a.compareTo(b);
      });

    final totalCost =
        filtered.fold<double>(0, (p, e) => p + e.totalCost);
    final totalDistance =
        filtered.fold<double>(0, (p, e) => p + e.distanceKm);

    final avgCostPerKm = totalDistance > 0
        ? totalCost / totalDistance
        : null;

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
                        leftTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: true,
                              reservedSize: 40,
                            )),
                        rightTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                child: _StatCard(
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

/// —————————————————————————
/// SOZLAMALAR – profil, tema, PIN-lock
/// —————————————————————————

class SettingsScreen extends StatelessWidget {
  final Box box;
  final AppProfile profile;
  const SettingsScreen({super.key, required this.box, required this.profile});

  void _changeTheme(BuildContext context, String mode) {
    box.put('themeMode', mode);
  }

  void _openProfileEdit(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProfileEditSheet(box: box),
    );
  }

  void _openPinSetup(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PinSetupSheet(box: box),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentTheme = box.get('themeMode', defaultValue: 'system') as String;
    final lockEnabled = box.get('lockEnabled', defaultValue: false) as bool;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 24,
              child: Text(
                (profile.name.isNotEmpty ? profile.name[0] : 'A')
                    .toUpperCase(),
              ),
            ),
            title: Text(profile.name),
            subtitle: Text(profile.carModel),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _openProfileEdit(context),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ko‘rinish (UI)',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Tizim'),
                      selected: currentTheme == 'system',
                      onSelected: (_) => _changeTheme(context, 'system'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Yorug‘'),
                      selected: currentTheme == 'light',
                      onSelected: (_) => _changeTheme(context, 'light'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Tungi'),
                      selected: currentTheme == 'dark',
                      onSelected: (_) => _changeTheme(context, 'dark'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Xavfsizlik', style: theme.textTheme.titleMedium),
                SwitchListTile(
                  value: lockEnabled,
                  onChanged: (_) => _openPinSetup(context),
                  title: const Text('Kirishda PIN qo‘yish'),
                  subtitle: const Text(
                    'Ilova ochilganda 4 xonali parol bilan himoyalash',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Face ID / Touch ID ni ham keyingi bosqichda qo‘shsa bo‘ladi – hozircha oddiy PIN-lock bor.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileEditSheet extends StatefulWidget {
  final Box box;
  const ProfileEditSheet({super.key, required this.box});

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  final _nameCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _carCtrl = TextEditingController();
  FuelType _fuelType = FuelType.petrolLpg;
  final _balonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final map = widget.box.get('profile') as Map<dynamic, dynamic>?;
    if (map != null) {
      final profile = AppProfile.fromMap(map);
      _nameCtrl.text = profile.name;
      _plateCtrl.text = profile.plateNumber ?? '';
      _carCtrl.text = profile.carModel;
      _fuelType = profile.fuelType;
      if (profile.gasTankCapacity != null) {
        _balonCtrl.text = profile.gasTankCapacity!.toStringAsFixed(1);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _plateCtrl.dispose();
    _carCtrl.dispose();
    _balonCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final map = widget.box.get('profile') as Map<dynamic, dynamic>?;
    final old =
        map != null ? AppProfile.fromMap(map) : null;

    final cap = _balonCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_balonCtrl.text.replaceAll(',', '.').trim());

    final profile = AppProfile(
      id: old?.id ?? 'profile_1',
      name: _nameCtrl.text.trim().isEmpty
          ? (old?.name ?? 'Haydovchi')
          : _nameCtrl.text.trim(),
      carModel: _carCtrl.text.trim().isEmpty
          ? (old?.carModel ?? 'Mening avtomobilim')
          : _carCtrl.text.trim(),
      fuelType: _fuelType,
      plateNumber: _plateCtrl.text.trim().isEmpty
          ? null
          : _plateCtrl.text.trim(),
      gasTankCapacity: cap,
    );

    widget.box.put('profile', profile.toMap());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              'Profil va mashina ma’lumotlari',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Ism',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _plateCtrl,
              decoration: const InputDecoration(
                labelText: 'Davlat raqami',
                prefixIcon: Icon(Icons.credit_card),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _carCtrl,
              decoration: const InputDecoration(
                labelText: 'Avtomobil',
                prefixIcon: Icon(Icons.directions_car),
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                RadioListTile<FuelType>(
                  value: FuelType.petrol,
                  groupValue: _fuelType,
                  title: const Text('Faqat benzin'),
                  onChanged: (v) => setState(() {
                    _fuelType = v!;
                  }),
                ),
                RadioListTile<FuelType>(
                  value: FuelType.petrolLpg,
                  groupValue: _fuelType,
                  title: const Text('Benzin + Propan'),
                  onChanged: (v) => setState(() {
                    _fuelType = v!;
                  }),
                ),
                RadioListTile<FuelType>(
                  value: FuelType.petrolCng,
                  groupValue: _fuelType,
                  title: const Text('Benzin + Metan'),
                  onChanged: (v) => setState(() {
                    _fuelType = v!;
                  }),
                ),
              ],
            ),
            if (_fuelType != FuelType.petrol) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _balonCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _fuelType == FuelType.petrolLpg
                      ? 'Propan balon (litr)'
                      : 'Metan balon (m³ taxminiy)',
                  prefixIcon: const Icon(Icons.local_gas_station),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Saqlash'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// —————————————————————————
/// PIN LOCK – kirishda parol
/// —————————————————————————

class LockScreen extends StatefulWidget {
  final Box box;
  const LockScreen({super.key, required this.box});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _check() {
    final saved = widget.box.get('lockPin') as String?;
    if (saved == null || saved.isEmpty) {
      // PIN yo‘q – lock o‘chirilgan deb hisoblaymiz
      widget.box.put('lockEnabled', false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainShell(box: widget.box)),
      );
      return;
    }

    if (_pinCtrl.text == saved) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainShell(box: widget.box)),
      );
    } else {
      setState(() {
        _error = 'PIN noto‘g‘ri';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 0, 40, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              const Text(
                'Kirish uchun PIN kiriting',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pinCtrl,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '****',
                  errorText: _error,
                ),
                onSubmitted: (_) => _check(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _check,
                  child: const Text('Kirish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PinSetupSheet extends StatefulWidget {
  final Box box;
  const PinSetupSheet({super.key, required this.box});

  @override
  State<PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<PinSetupSheet> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  void _save() {
    if (_pin1.text.length != 4 || _pin1.text != _pin2.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN mos kelmadi yoki xato kiritildi')),
      );
      return;
    }
    widget.box.put('lockPin', _pin1.text);
    widget.box.put('lockEnabled', true);
    Navigator.of(context).pop();
  }

  void _disable() {
    widget.box.delete('lockPin');
    widget.box.put('lockEnabled', false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasPin =
        (widget.box.get('lockPin') as String?)?.isNotEmpty == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
            hasPin ? 'PIN ni o‘zgartirish' : 'PIN o‘rnatish',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin1,
            maxLength: 4,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Yangi PIN',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pin2,
            maxLength: 4,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Yangi PIN (takror)',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (hasPin)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _disable,
                    child: const Text('PINni o‘chirish'),
                  ),
                ),
              if (hasPin) const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Saqlash'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
