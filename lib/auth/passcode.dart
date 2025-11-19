import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PinSetupSheet extends StatefulWidget {
  final Box box;
  const PinSetupSheet({super.key, required this.box});

  @override
  State<PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<PinSetupSheet> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  bool _enabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _enabled = widget.box.get('lockEnabled', defaultValue: false) as bool;
  }

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  void _save() {
    if (!_enabled) {
      widget.box
        ..put('lockEnabled', false)
        ..put('lockPin', '');
      Navigator.of(context).pop();
      return;
    }

    if (_pin1.text.length != 4 || _pin2.text.length != 4) {
      setState(() {
        _error = 'PIN 4 ta raqamdan iborat bo‘lishi kerak';
      });
      return;
    }

    if (_pin1.text != _pin2.text) {
      setState(() {
        _error = 'PINlar mos emas';
      });
      return;
    }

    widget.box
      ..put('lockEnabled', true)
      ..put('lockPin', _pin1.text);

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
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
            const Text(
              'PIN / parol sozlamalari',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _enabled,
              onChanged: (v) {
                setState(() {
                  _enabled = v;
                  _error = null;
                });
              },
              title: const Text('Ilovani PIN bilan bloklash'),
              subtitle: const Text(
                'Ilova ochilganda 4 xonali parol so‘ralsin',
              ),
            ),
            if (_enabled) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _pin1,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'PIN kiriting',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pin2,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'PINni qayta kiriting',
                  errorText: _error,
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
