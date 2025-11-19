import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../auth/passcode.dart';
import '../core/models.dart';
import '../core/storage.dart';

class SettingsScreen extends StatelessWidget {
  final Box box;
  final AppProfile profile;
  const SettingsScreen({super.key, required this.box, required this.profile});

  void _changeTheme(String mode) {
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

  Future<bool> _confirmByPin(BuildContext context) async {
    final String? savedPin = box.get('lockPin') as String?;
    if (savedPin == null || savedPin.isEmpty) {
      return true;
    }

    final TextEditingController controller = TextEditingController();
    String? error;

    final bool ok = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setState) {
                return AlertDialog(
                  title: const Text('PIN ni tasdiqlang'),
                  content: TextField(
                    controller: controller,
                    obscureText: true,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '****',
                      errorText: error,
                    ),
                    onSubmitted: (_) {
                      if (controller.text == savedPin) {
                        Navigator.of(ctx).pop(true);
                      } else {
                        setState(() {
                          error = 'PIN noto‘g‘ri';
                        });
                      }
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Bekor qilish'),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (controller.text == savedPin) {
                          Navigator.of(ctx).pop(true);
                        } else {
                          setState(() {
                            error = 'PIN noto‘g‘ri';
                          });
                        }
                      },
                      child: const Text('Tasdiqlash'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    return ok;
  }

  Future<void> _clearAllData(BuildContext context) async {
    final bool pinOk = await _confirmByPin(context);
    if (!pinOk) return;

    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Ma’lumotlarni tozalash'),
              content: const Text(
                'Barcha yoqilg‘i yozuvlari va ular bilan bog‘liq statistika o‘chiriladi. Davom etasizmi?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Bekor qilish'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Tozalash'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirm) return;

    await saveEntries(box, []);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ma’lumotlar muvaffaqiyatli tozalandi'),
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Profilni chiqarish'),
              content: const Text(
                'Profilni chiqarish natijasida hozirgi haydovchi ma’lumotlari o‘chadi. '
                'Yozilgan yoqilg‘i ma’lumotlari esa saqlanib qoladi (davlat raqam bo‘yicha qayta biriktiriladi). Davom etasizmi?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Bekor qilish'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Profildan chiqish'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirm) return;

    await box.delete('profile');
    await box.put('lockEnabled', false);
    await box.put('lockPin', '');
    // Face ID default holat (yoqilgan)
    await box.put('biometricEnabled', true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Profil o‘chirildi. Ilovani qayta ochganingizda yangi profil yaratish oynasi chiqadi.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentTheme =
        box.get('themeMode', defaultValue: 'system') as String;
    final lockEnabled =
        box.get('lockEnabled', defaultValue: false) as bool;
    final biometricEnabled =
        box.get('biometricEnabled', defaultValue: true) as bool;

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
            subtitle: Text(
              '${profile.carModel} • ${profile.plateNumber ?? 'Davlat raqam yo‘q'}',
            ),
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
                      onSelected: (_) => _changeTheme('system'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Yorug‘'),
                      selected: currentTheme == 'light',
                      onSelected: (_) => _changeTheme('light'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Tungi'),
                      selected: currentTheme == 'dark',
                      onSelected: (_) => _changeTheme('dark'),
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
                const SizedBox(height: 6),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('PIN / parol'),
                  subtitle: Text(
                    lockEnabled ? 'PIN yoqilgan' : 'PIN o‘chirilgan',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openPinSetup(context),
                ),
                SwitchListTile(
                  value: biometricEnabled,
                  onChanged: (v) {
                    box.put('biometricEnabled', v);
                  },
                  title: const Text('Face ID / Touch ID'),
                  subtitle: const Text(
                    'Qurilmada mavjud bo‘lsa, tezkor kirish uchun biometrik autentifikatsiya.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: theme.colorScheme.errorContainer.withOpacity(0.15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ma’lumotlarni tozalash',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Barcha yoqilg‘i yozuvlari va statistika nol holatga qaytariladi. '
                  'Agar PIN o‘rnatilgan bo‘lsa, avval PIN orqali tasdiqlanadi.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Ma’lumotlarni tozalash'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => _clearAllData(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: theme.colorScheme.errorContainer.withOpacity(0.25),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profildan chiqish',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Profildan chiqilganda haydovchi ma’lumotlari tozalanadi. '
                  'Ammo yozilgan yoqilg‘i yozuvlari saqlanib qoladi – keyinchalik shu davlat raqam bilan qayta biriktiriladi.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Profildan chiqish'),
                    style: FilledButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => _logout(context),
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

  String _selectedCar = 'Chevrolet Cobalt';

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

      final idx = _uzbekCarModels.indexWhere(
        (m) => m == profile.carModel,
      );
      if (idx != -1) {
        _selectedCar = _uzbekCarModels[idx];
      } else {
        _selectedCar = 'Boshqa (o‘zim kiritaman)';
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
    final old = map != null ? AppProfile.fromMap(map) : null;

    if (_plateCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Davlat raqamini kiriting'),
        ),
      );
      return;
    }

    final cap = _balonCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_balonCtrl.text.replaceAll(',', '.').trim());

    String carModel;
    if (_selectedCar == 'Boshqa (o‘zim kiritaman)') {
      carModel = _carCtrl.text.trim().isEmpty
          ? (old?.carModel ?? 'Mening avtomobilim')
          : _carCtrl.text.trim();
    } else {
      carModel = _selectedCar;
    }

    final profile = AppProfile(
      id: old?.id ?? 'profile_1',
      name: _nameCtrl.text.trim().isEmpty
          ? (old?.name ?? 'Haydovchi')
          : _nameCtrl.text.trim(),
      carModel: carModel,
      fuelType: _fuelType,
      plateNumber: _plateCtrl.text.trim(),
      gasTankCapacity: cap,
    );

    widget.box.put('profile', profile.toMap());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                'Profilni tahrirlash',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ism',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _plateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Davlat raqam',
                ),
              ),
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
                onChanged: (v) {
                  setState(() {
                    _selectedCar = v ?? _selectedCar;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Avtomobil modeli',
                ),
              ),
              if (_selectedCar == 'Boshqa (o‘zim kiritaman)') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _carCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Model nomini kiriting',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<FuelType>(
                value: _fuelType,
                items: const [
                  DropdownMenuItem(
                    value: FuelType.petrol,
                    child: Text('Faqat benzin'),
                  ),
                  DropdownMenuItem(
                    value: FuelType.petrolLpg,
                    child: Text('Benzin + Propan (LPG)'),
                  ),
                  DropdownMenuItem(
                    value: FuelType.petrolCng,
                    child: Text('Benzin + Metan (CNG)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _fuelType = v;
                    });
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Yoqilg‘i turi',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _balonCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Bak sig‘imi (litr, ixtiyoriy)',
                ),
              ),
              const SizedBox(height: 20),
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
      ),
    );
  }
}
