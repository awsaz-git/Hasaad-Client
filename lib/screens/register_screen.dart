import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/governorate.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import '../utils/validators.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String? nationalId;
  final String? password;
  final Function(Locale) onLanguageChange;
  
  const RegisterScreen({
    super.key, 
    this.nationalId, 
    this.password,
    required this.onLanguageChange,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _landController = TextEditingController();
  
  int? _selectedGovernorateId;
  List<Governorate> _governorates = [];
  final _service = SupabaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGovernorates();
  }

  Future<void> _loadGovernorates() async {
    try {
      final data = await _service.getGovernorates();
      if (mounted) {
        setState(() => _governorates = data);
      }
    } catch (e) {
      print('Error loading governorates: $e');
    }
  }

  Future<void> _handleCompleteProfile() async {
    if (!_formKey.currentState!.validate() || _selectedGovernorateId == null) return;

    setState(() => _isLoading = true);
    try {
      final user = _service.currentUser;
      if (user != null) {
        final selectedGov = _governorates.firstWhere((g) => g.id == _selectedGovernorateId);
        
        final profile = Profile(
          id: user.id,
          nationalId: widget.nationalId ?? '',
          fullName: _nameController.text,
          governorate: selectedGov.nameEn,
          governorateId: _selectedGovernorateId!,
          landSize: double.parse(_landController.text),
        );
        
        await _service.createProfile(profile);

        if (mounted) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => HomeScreen(onLanguageChange: widget.onLanguageChange))
          );
        }
      }
    } catch (e) {
      print('Error completing profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.translate('registration_failed')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    const darkGreen = Color(0xFF005E4D);
    const primaryGreen = Color(0xFF00C897);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(l10n.translate('complete_profile'), style: GoogleFonts.cairo(fontSize: 18, color: darkGreen, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: darkGreen),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Image.asset('assets/logo with text.png', height: 100),
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
                    Text(l10n.translate('full_name'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      style: GoogleFonts.cairo(),
                      decoration: InputDecoration(
                        hintText: lang == 'ar' ? 'أحمد محمد' : 'John Doe',
                        prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (v) => Validators.validateRequired(v, l10n.translate('required_field')),
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.translate('governorate'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedGovernorateId,
                      style: GoogleFonts.cairo(color: Colors.black),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: _governorates.map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(g.getName(lang), style: GoogleFonts.cairo()),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedGovernorateId = val),
                      validator: (v) => v == null ? l10n.translate('required_field') : null,
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.translate('land_size'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _landController,
                      style: GoogleFonts.cairo(),
                      decoration: InputDecoration(
                        hintText: '10.5',
                        prefixIcon: const Icon(Icons.square_foot_outlined, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => Validators.validateLandSize(v, l10n.translate('invalid_land_size')),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleCompleteProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                l10n.translate('submit'), 
                                style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
