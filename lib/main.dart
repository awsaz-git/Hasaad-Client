import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'utils/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/register_screen.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize Local Notifications
  await NotificationService().init();

  runApp(const HasaadApp());
}

class HasaadApp extends StatefulWidget {
  const HasaadApp({super.key});

  @override
  State<HasaadApp> createState() => _HasaadAppState();
}

class _HasaadAppState extends State<HasaadApp> {
  Locale _locale = const Locale('ar');

  void _setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Reverted to simple theme based on brand color #015E54
    const brandGreen = Color(0xFF015E54);

    return MaterialApp(
      title: 'Hasaad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandGreen,
          primary: brandGreen,
          secondary: brandGreen,
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.cairoTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: brandGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: brandGreen,
            side: const BorderSide(color: brandGreen),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: brandGreen, width: 2),
          ),
          labelStyle: GoogleFonts.cairo(color: brandGreen),
          hintStyle: GoogleFonts.cairo(color: Colors.grey),
        ),
      ),
      locale: _locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AuthCheck(onLanguageChange: _setLocale),
    );
  }
}

class AuthCheck extends StatefulWidget {
  final Function(Locale) onLanguageChange;
  const AuthCheck({super.key, required this.onLanguageChange});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  final _service = SupabaseService();
  bool _checking = true;
  Widget? _targetScreen;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initAuthListener();
    _checkSession();
  }

  void _initAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        if (mounted) {
          setState(() {
            _targetScreen = LoginScreen(onLanguageChange: widget.onLanguageChange);
          });
        }
      } else if (data.event == AuthChangeEvent.signedIn) {
        _checkSession();
      }
    });
  }

  Future<void> _checkSession() async {
    if (!mounted) return;
    setState(() => _checking = true);

    final session = Supabase.instance.client.auth.currentSession;
    
    if (session == null) {
      _setTarget(LoginScreen(onLanguageChange: widget.onLanguageChange));
      return;
    }

    try {
      final profile = await _service.getProfile(session.user.id);
      if (profile == null) {
        _setTarget(RegisterScreen(onLanguageChange: widget.onLanguageChange));
      } else {
        _setTarget(HomeScreen(onLanguageChange: widget.onLanguageChange));
      }
    } catch (e) {
      debugPrint('Error checking session profile: $e');
      _setTarget(LoginScreen(onLanguageChange: widget.onLanguageChange));
    }
  }

  void _setTarget(Widget screen) {
    if (mounted) {
      setState(() {
        _targetScreen = screen;
        _checking = false;
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || _targetScreen == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF015E54)),
        ),
      );
    }
    return _targetScreen!;
  }
}
