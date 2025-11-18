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
        ),
      ),
    );
  }
}
