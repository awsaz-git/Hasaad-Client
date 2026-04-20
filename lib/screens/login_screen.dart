import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import '../utils/validators.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final Function(Locale) onLanguageChange;
  const LoginScreen({super.key, required this.onLanguageChange});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _service = SupabaseService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      AuthResponse? authResponse;
      try {
        authResponse = await _service.signIn(_idController.text, _passwordController.text);
      } catch (e) {
        print("Login attempt failed: $e");
      }
      
      if (authResponse == null || authResponse.user == null) {
        try {
          authResponse = await _service.signUp(_idController.text, _passwordController.text);
        } on AuthException catch (ae) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ae.message)),
            );
          }
          setState(() => _isLoading = false);
          return;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.translate('login_failed'))),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      if (authResponse?.user != null) {
        final profile = await _service.getProfile(authResponse!.user!.id);
        if (profile == null) {
           if (mounted) {
             Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(
               nationalId: _idController.text,
               password: _passwordController.text,
               onLanguageChange: widget.onLanguageChange,
             )));
           }
        } else {
           if (mounted) {
             Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(onLanguageChange: widget.onLanguageChange)));
           }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.translate('login_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    const darkGreen = Color(0xFF005E4D);
    const primaryGreen = Color(0xFF00C897);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: InkWell(
              onTap: () {
                widget.onLanguageChange(isAr ? const Locale('en') : const Locale('ar'));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: darkGreen.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(
                      isAr ? '🇬🇧 EN' : '🇯🇴 عربي',
                      style: GoogleFonts.cairo(
                        color: darkGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Image.asset('assets/logo with text.png', height: 180), // Made logo bigger (was 120)
              const SizedBox(height: 30),
              Text(
                l10n.translate('login'),
                style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.translate('national_id'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _idController,
                      textAlign: isAr ? TextAlign.right : TextAlign.left,
                      decoration: InputDecoration(
                        hintText: 'XXXXXXXXXX',
                        suffixIcon: const Icon(Icons.badge_outlined, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => Validators.validateNationalId(v, l10n.translate('invalid_national_id')),
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.translate('password'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textAlign: isAr ? TextAlign.right : TextAlign.left,
                      decoration: InputDecoration(
                        hintText: '........',
                        suffixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                        prefixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (v) => Validators.validateRequired(v, l10n.translate('required_field')),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                l10n.translate('login_via_sanad'), 
                                style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  l10n.translate('new_user_hint'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
