import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/models.dart';
import 'home/base.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox('autox_box');
  runApp(AutoXApp(box: box));
}

class AutoXApp extends StatelessWidget {
  final Box box;
  const AutoXApp({super.key, required this.box});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box<dynamic> box, _) {
        final themeString =
            box.get('themeMode', defaultValue: 'system') as String;
        final themeMode = switch (themeString) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };

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

/// LIGHT / DARK THEME

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
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: primary,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
    ),
  );
}

/// LOCK SCREEN (kirishda PIN so'rovi)

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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.fromLTRB(40, 0, 40, bottomInset + 16),
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
      ),
    );
  }
}
