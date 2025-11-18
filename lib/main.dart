import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Sana formatlash: 18.11.2025 ko'rinishida
String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day.$month.$year';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const AutoXarajatApp());
}

class AutoXarajatApp extends StatefulWidget {
  const AutoXarajatApp({super.key});

  @override
  State<AutoXarajatApp> createState() => _AutoXarajatAppState();
}

class _AutoXarajatAppState extends State<AutoXarajatApp> {
  late final FuelRepository _repository;
  late final Future<List<RefuelEntry>> _initialFuture;

  @override
  void initState() {
    super.initState();
    _repository = FuelRepository();
    _initialFuture = _init();
  }

  Future<List<RefuelEntry>> _init() async {
    await _repository.init();
    return _repository.loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00A884),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'AvtoXarajat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF020817),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: colorScheme.onBackground,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: FutureBuilder<List<RefuelEntry>>(
        future: _initialFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SplashScreen();
          }
          final entries = snapshot.data ?? <RefuelEntry>[];
          return HomeShell(
            repository: _repository,
            initialEntries: entries,
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// --- MODEL LAYER ---

class RefuelEntry {
  final String id;
  final DateTime date;
  final double distanceKm; // shu yo'lga sarflangan masofa
  final double liters; // quyilgan litr
  final double pricePerLiter; // 1 litr narxi so'mda
  final bool isFull; // full quyildimi yoki qismanmi

  RefuelEntry({
    required this.id,
    required this.date,
    required this.distanceKm,
    required this.liters,
    required this.pricePerLiter,
    required this.isFull,
  });

  double get cost => liters * pricePerLiter;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'distanceKm': distanceKm,
        'liters': liters,
        'pricePerLiter': pricePerLiter,
        'isFull': isFull,
      };

  factory RefuelEntry.fromJson(Map<String, dynamic> json) {
    return RefuelEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      liters: (json['liters'] as num).toDouble(),
      pricePerLiter: (json['pricePerLiter'] as num).toDouble(),
      isFull: json['isFull'] as bool? ?? false,
    );
  }
}

class AppSettings {
  final bool defaultFullTank;

  AppSettings({required this.defaultFullTank});

  Map<String, dynamic> toJson() => {
        'defaultFullTank': defaultFullTank,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        defaultFullTank: json['defaultFullTank'] as bool? ?? true,
      );

  static AppSettings get initial => AppSettings(defaultFullTank: true);
}

class FuelStats {
  final double totalDistance;
  final double totalLiters;
  final double totalCost;
  final double avgPer100km;
  final double avgPricePerLiter;

  FuelStats({
    required this.totalDistance,
    required this.totalLiters,
    required this.totalCost,
    required this.avgPer100km,
    required this.avgPricePerLiter,
  });

  factory FuelStats.fromEntries(List<RefuelEntry> entries) {
    var distance = 0.0;
    var liters = 0.0;
    var cost = 0.0;

    for (final e in entries) {
      distance += e.distanceKm;
      liters += e.liters;
      cost += e.cost;
    }

    final avgPer100 = distance > 0 ? (liters * 100.0) / distance : 0.0;
    final avgPrice = liters > 0 ? cost / liters : 0.0;

    return FuelStats(
      totalDistance: distance,
      totalLiters: liters,
      totalCost: cost,
      avgPer100km: avgPer100,
      avgPricePerLiter: avgPrice,
    );
  }
}

/// --- REPOSITORY: Hive + iCloud (MethodChannel) ---

class FuelRepository {
  static const _boxName = 'autoxarajat_box';
  static const _entriesKey = 'entries_json';
  static const _settingsKey = 'settings_json';

  static const MethodChannel _iCloudChannel = MethodChannel('icloud_sync');

  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  Future<List<RefuelEntry>> loadEntries() async {
    final local = _loadEntriesFromLocal();

    // iCloud'dan o'qib ko'ramiz, bo'lsa – ustun
    try {
      final cloud = await _loadEntriesFromICloud();
      if (cloud.isNotEmpty) {
        await _saveEntriesToLocal(cloud);
        return cloud;
      }
    } catch (_) {
      // iCloud xatolarini e'tiborga olmasak ham bo'ladi, local ishlayveradi
    }

    return local;
  }

  List<RefuelEntry> _loadEntriesFromLocal() {
    final raw = _box.get(_entriesKey);
    if (raw == null || raw.isEmpty) return <RefuelEntry>[];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map(
          (e) => RefuelEntry.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> _saveEntriesToLocal(List<RefuelEntry> entries) async {
    final raw =
        jsonEncode(entries.map((e) => e.toJson()).toList(growable: false));
    await _box.put(_entriesKey, raw);
  }

  Future<void> saveEntries(List<RefuelEntry> entries) async {
    await _saveEntriesToLocal(entries);
    try {
      final entriesJson =
          jsonEncode(entries.map((e) => e.toJson()).toList(growable: false));
      final updatedAt = DateTime.now().toIso8601String();
      await _iCloudChannel.invokeMethod<void>('saveEntries', {
        'entriesJson': entriesJson,
        'updatedAt': updatedAt,
      });
    } catch (_) {
      // iCloud bo'lmasa ham app ishlayveradi
    }
  }

  Future<List<RefuelEntry>> _loadEntriesFromICloud() async {
    final result =
        await _iCloudChannel.invokeMethod<dynamic>('loadEntries');
    if (result == null) return <RefuelEntry>[];

    final map = Map<String, dynamic>.from(result as Map);
    final entriesJson = map['entriesJson'] as String?;
    if (entriesJson == null || entriesJson.isEmpty) {
      return <RefuelEntry>[];
    }
    final list = jsonDecode(entriesJson) as List<dynamic>;
    return list
        .map(
          (e) => RefuelEntry.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<AppSettings> loadSettings() async {
    final raw = _box.get(_settingsKey);
    if (raw == null || raw.isEmpty) return AppSettings.initial;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(map);
    } catch (_) {
      return AppSettings.initial;
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final raw = jsonEncode(settings.toJson());
    await _box.put(_settingsKey, raw);
  }
}

/// --- SHELL: Bottom navigation bilan 3 ta sahifa ---

class HomeShell extends StatefulWidget {
  final FuelRepository repository;
  final List<RefuelEntry> initialEntries;

  const HomeShell({
    super.key,
    required this.repository,
    required this.initialEntries,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late List<RefuelEntry> _entries;
  late AppSettings _settings;
  int _currentIndex = 0;
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _entries = List<RefuelEntry>.from(widget.initialEntries);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await widget.repository.loadSettings();
    setState(() {
      _settings = s;
      _isLoadingSettings = false;
    });
  }

  Future<void> _addOrEditEntry({RefuelEntry? entry}) async {
    final result = await showModalBottomSheet<RefuelEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF020617),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: RefuelFormSheet(
            initial: entry,
            defaultFullTank: _settings.defaultFullTank,
          ),
        );
      },
    );

    if (result == null) return;

    setState(() {
      final index = _entries.indexWhere((e) => e.id == result.id);
      if (index == -1) {
        _entries.add(result);
      } else {
        _entries[index] = result;
      }
      _entries.sort((a, b) => b.date.compareTo(a.date));
    });

    await widget.repository.saveEntries(_entries);
  }

  Future<void> _deleteEntry(RefuelEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('O‘chirish'),
        content: const Text('Bu yozuvni o‘chirmoqchimisiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ha, o‘chir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _entries.removeWhere((e) => e.id == entry.id);
    });
    await widget.repository.saveEntries(_entries);
  }

  Future<void> _updateSettings(AppSettings newSettings) async {
    setState(() {
      _settings = newSettings;
    });
    await widget.repository.saveSettings(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSettings) {
      return const SplashScreen();
    }

    final stats = FuelStats.fromEntries(_entries);

    final pages = [
      DashboardPage(
        entries: _entries,
        stats: stats,
        onAddOrEdit: _addOrEditEntry,
        onDelete: _deleteEntry,
      ),
      StatsPage(
        entries: _entries,
        stats: stats,
      ),
      SettingsPage(
        settings: _settings,
        stats: stats,
        onSettingsChanged: _updateSettings,
        onClearAll: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Hammasini o‘chirish'),
              content: const Text(
                  'Barcha yozuvlar o‘chiriladi va iCloud bilan ham sinxronlashadi. Davom etamizmi?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Bekor qilish'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Ha, o‘chir'),
                ),
              ],
            ),
          );
          if (ok == true) {
            setState(() {
              _entries.clear();
            });
            await widget.repository.saveEntries(_entries);
          }
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AvtoXarajat'),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: pages[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() {
            _currentIndex = i;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_gas_station_outlined),
            selectedIcon: Icon(Icons.local_gas_station),
            label: 'Asosiy',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
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
          ? FloatingActionButton.extended(
              onPressed: () => _addOrEditEntry(),
              icon: const Icon(Icons.add),
              label: const Text('Yozuv qo‘shish'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

/// --- DASHBOARD SAHIFA ---

class DashboardPage extends StatelessWidget {
  final List<RefuelEntry> entries;
  final FuelStats stats;
  final Future<void> Function({RefuelEntry? entry}) onAddOrEdit;
  final Future<void> Function(RefuelEntry entry) onDelete;

  const DashboardPage({
    super.key,
    required this.entries,
    required this.stats,
    required this.onAddOrEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nexia 3 — Propan',
            style:
                theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Bugungi sarf va umumiy statistika',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Jami yo‘l',
                  valueText: '${stats.totalDistance.toStringAsFixed(0)} km',
                  icon: Icons.social_distance,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Jami gaz',
                  valueText: '${stats.totalLiters.toStringAsFixed(1)} L',
                  icon: Icons.local_gas_station,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Jami xarajat',
                  valueText: '${stats.totalCost.toStringAsFixed(0)} so‘m',
                  icon: Icons.payments,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'O‘rtacha 100 km',
                  valueText: '${stats.avgPer100km.toStringAsFixed(1)} L',
                  icon: Icons.speed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'So‘nggi quyishlar',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (entries.isNotEmpty)
                Text(
                  '${entries.length} ta yozuv',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.local_gas_station_outlined,
                    size: 40,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hali ma’lumot kiritilmadi',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Yangi gaz quyganingizda “Yozuv qo‘shish” tugmasi orqali kiritib boring.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (final e in entries)
                  _RefuelTile(
                    entry: e,
                    onTap: () => onAddOrEdit(entry: e),
                    onDelete: () => onDelete(e),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String valueText;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.valueText,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF020617),
            Color(0xFF020617),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  valueText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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

class _RefuelTile extends StatelessWidget {
  final RefuelEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RefuelTile({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateText = _formatDate(entry.date);
    final distanceText = '${entry.distanceKm.toStringAsFixed(0)} km';
    final litersText = '${entry.liters.toStringAsFixed(1)} L';
    final costText = entry.cost.toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF22C55E),
                      Color(0xFF16A34A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  entry.isFull
                      ? Icons.local_gas_station
                      : Icons.local_gas_station_outlined,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      litersText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$distanceText • ${entry.isFull ? 'Full' : 'Qisman'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateText,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$costText so‘m',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// --- Yozuv qo'shish / tahrirlash uchun bottom sheet ---

class RefuelFormSheet extends StatefulWidget {
  final RefuelEntry? initial;
  final bool defaultFullTank;

  const RefuelFormSheet({
    super.key,
    this.initial,
    required this.defaultFullTank,
  });

  @override
  State<RefuelFormSheet> createState() => _RefuelFormSheetState();
}

class _RefuelFormSheetState extends State<RefuelFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late TextEditingController _distanceCtrl;
  late TextEditingController _litersCtrl;
  late TextEditingController _priceCtrl;
  late bool _isFull;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _date = initial?.date ?? DateTime.now();
    _distanceCtrl =
        TextEditingController(text: initial?.distanceKm.toString() ?? '');
    _litersCtrl =
        TextEditingController(text: initial?.liters.toString() ?? '');
    _priceCtrl = TextEditingController(
        text: initial?.pricePerLiter.toStringAsFixed(0) ?? '');
    _isFull = initial?.isFull ?? widget.defaultFullTank;
  }

  @override
  void dispose() {
    _distanceCtrl.dispose();
    _litersCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final distance =
        double.parse(_distanceCtrl.text.replaceAll(',', '.'));
    final liters =
        double.parse(_litersCtrl.text.replaceAll(',', '.'));
    final price =
        double.parse(_priceCtrl.text.replaceAll(',', '.'));

    final id = widget.initial?.id ??
        'refuel_${DateTime.now().microsecondsSinceEpoch}';

    final entry = RefuelEntry(
      id: id,
      date: _date,
      distanceKm: distance,
      liters: liters,
      pricePerLiter: price,
      isFull: _isFull,
    );

    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            isEdit ? 'Yozuvni tahrirlash' : 'Yangi yozuv',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_note, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(_date),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  const Icon(Icons.calendar_today, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Masofa (km)',
                  hint: 'Masofa',
                  controller: _distanceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LabeledField(
                  label: 'Litrlari',
                  hint: 'Necha litr',
                  controller: _litersCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: '1 litr narxi (so‘m)',
            hint: 'Masalan 5500',
            controller: _priceCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Switch(
                      value: _isFull,
                      onChanged: (v) {
                        setState(() {
                          _isFull = v;
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    const Text('Full quyildi'),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _submit,
                icon: Icon(isEdit ? Icons.save : Icons.check),
                label: Text(isEdit ? 'Saqlash' : 'Qo‘shish'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Majburiy maydon';
            }
            final value =
                double.tryParse(val.replaceAll(',', '.'));
            if (value == null || value <= 0) {
              return 'To‘g‘ri son kiriting';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFF020617),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

/// --- STATISTIKA SAHIFA ---

class StatsPage extends StatelessWidget {
  final List<RefuelEntry> entries;
  final FuelStats stats;

  const StatsPage({
    super.key,
    required this.entries,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = List<RefuelEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistika',
            style:
                theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Yo‘qilg‘i sarfi bo‘yicha umumiy natijalar',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF020617),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                _StatsRow(
                  label: 'Jami yo‘l',
                  value: '${stats.totalDistance.toStringAsFixed(0)} km',
                ),
                _StatsRow(
                  label: 'Jami gaz',
                  value: '${stats.totalLiters.toStringAsFixed(1)} L',
                ),
                _StatsRow(
                  label: 'Jami xarajat',
                  value: '${stats.totalCost.toStringAsFixed(0)} so‘m',
                ),
                _StatsRow(
                  label: 'O‘rtacha 100 km sarf',
                  value: '${stats.avgPer100km.toStringAsFixed(1)} L',
                ),
                _StatsRow(
                  label: 'O‘rtacha 1 L narx',
                  value: '${stats.avgPricePerLiter.toStringAsFixed(0)} so‘m',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Har safar bo‘yicha 100 km sarf',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                'Hali ma’lumot yo‘q. Bir nechta yozuv kiriting.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
            Column(
              children: sorted.map((e) {
                final per100 = e.distanceKm > 0
                    ? e.liters * 100.0 / e.distanceKm
                    : 0.0;
                final date = _formatDate(e.date);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF020617),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          date,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '${per100.toStringAsFixed(1)} L / 100 km',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatsRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// --- SOZLAMALAR SAHIFA ---

class SettingsPage extends StatelessWidget {
  final AppSettings settings;
  final FuelStats stats;
  final Future<void> Function(AppSettings newSettings) onSettingsChanged;
  final Future<void> Function() onClearAll;

  const SettingsPage({
    super.key,
    required this.settings,
    required this.stats,
    required this.onSettingsChanged,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        Text(
          'Sozlamalar',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Avtomobilingiz va saqlash sozlamalari',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF020617),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              _SettingSwitchTile(
                title: 'Full quyish — standart',
                subtitle:
                    'Yangi yozuv qo‘shayotganda “Full quyildi” switche avtomatik yoqilgan bo‘ladi.',
                value: settings.defaultFullTank,
                onChanged: (v) {
                  onSettingsChanged(
                    AppSettings(defaultFullTank: v),
                  );
                },
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.cloud_done_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ma’lumotlar iCloud + telefon xotirasida saqlanadi. '
                      'Ilovani o‘chirib, qayta o‘rnatsangiz ham qayta yuklab olasiz.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF020617),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xavfsizlik',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'Jami yo‘l: ${stats.totalDistance.toStringAsFixed(0)} km.\n'
                'Jami gaz: ${stats.totalLiters.toStringAsFixed(1)} L.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: onClearAll,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Barcha ma’lumotni o‘chirish'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
