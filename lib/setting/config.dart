import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../auth/passcode.dart';
import '../core/models.dart';

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
                Text('Ko‘rinish (UI)', style: theme.textTheme.titleMedium),
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
    final old = map != null ? AppProfile.fromMap(map) : null;

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
      plateNumber:
          _plateCtrl.text.trim().isEmpty ? null : _plateCtrl.text.trim(),
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
      ),
    );
  }
}
