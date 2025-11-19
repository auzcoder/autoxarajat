import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';

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
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
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
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

/// ==================
///   LOCK SCREEN
/// ==================

class LockScreen extends StatefulWidget {
  final Box box;
  const LockScreen({super.key, required this.box});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _pinCtrl = TextEditingController();
  String? _error;

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _isAuthenticating = false;
  String _biometricLabel = 'Face ID';
  IconData _biometricIcon = Icons.face_rounded;

  // Animatsiya holatlari
  double _cardOffsetY = 0.08;
  double _cardOpacity = 0.0;
  double _iconScale = 0.8;
  bool _autoPrompted = false;

  @override
  void initState() {
    super.initState();
    _runEntryAnimation();
    _initBiometrics();
  }

  void _runEntryAnimation() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      setState(() {
        _cardOffsetY = 0.0;
        _cardOpacity = 1.0;
        _iconScale = 1.0;
      });
    });
  }

  Future<void> _initBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();

      if (!mounted || !canCheck || !supported) return;

      // Foydalanuvchi Face ID / Touch ID ni sozlamadan o‘chirgan bo‘lishi mumkin
      final bool enabled =
          widget.box.get('biometricEnabled', defaultValue: true) as bool;
      if (!enabled) return;

      final types = await _localAuth.getAvailableBiometrics();

      String label;
      IconData icon;
      if (types.contains(BiometricType.face)) {
        label = 'Face ID';
        icon = Icons.face_rounded;
      } else if (types.contains(BiometricType.fingerprint)) {
        label = 'Touch ID';
        icon = Icons.fingerprint_rounded;
      } else {
        label = 'Biometrik';
        icon = Icons.verified_user_rounded;
      }

      if (!mounted) return;
      setState(() {
        _canCheckBiometrics = true;
        _biometricLabel = label;
        _biometricIcon = icon;
      });

      // Ekranga kirgandan keyin ozgina kutib, avto Face ID / Touch ID
      if (!_autoPrompted) {
        _autoPrompted = true;
        await Future.delayed(const Duration(milliseconds: 450));
        if (mounted) {
          _authWithBiometrics();
        }
      }
    } on PlatformException {
      // biometrik yo‘q / xato – PIN bo‘yicha kiraveradi
    }
  }

  Future<void> _authWithBiometrics() async {
    if (_isAuthenticating || !_canCheckBiometrics) return;

    try {
      setState(() {
        _isAuthenticating = true;
        _error = null;
      });

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason:
            'Ilovaga kirish uchun $_biometricLabel dan foydalaning',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;

      if (didAuthenticate) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => MainShell(box: widget.box)),
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Biometric error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _checkPin() {
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
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary.withOpacity(0.14),
              cs.secondary.withOpacity(0.16),
              cs.surface.withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutBack,
                    scale: _iconScale,
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            cs.primary,
                            cs.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withOpacity(0.35),
                            blurRadius: 26,
                            offset: const Offset(0, 14),
                          )
                        ],
                      ),
                      child: Icon(
                        _biometricIcon,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'AutoXarajat bloklangan',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kirish uchun Face ID / Touch ID yoki PIN dan foydalaning',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color
                          ?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 26),
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    offset: Offset(0, _cardOffsetY),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 400),
                      opacity: _cardOpacity,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          color: cs.surface.withOpacity(0.96),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 26,
                              offset: const Offset(0, 18),
                            )
                          ],
                          border: Border.all(
                            color: cs.primary.withOpacity(0.06),
                          ),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _pinCtrl,
                              obscureText: true,
                              maxLength: 4,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                labelText: '4 xonali PIN',
                                counterText: '',
                                errorText: _error,
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                              ),
                              onSubmitted: (_) => _checkPin(),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _checkPin,
                                child: const Text('PIN bilan kirish'),
                              ),
                            ),
                            if (_canCheckBiometrics) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _isAuthenticating
                                    ? null
                                    : _authWithBiometrics,
                                icon: _isAuthenticating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(_biometricIcon),
                                label: Text(
                                  _isAuthenticating
                                      ? 'Tasdiqlanmoqda...'
                                      : '$_biometricLabel bilan tezkor kirish',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
