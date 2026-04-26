import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';

class SuggestFeatureScreen extends StatefulWidget {
  const SuggestFeatureScreen({super.key});

  @override
  State<SuggestFeatureScreen> createState() => _SuggestFeatureScreenState();
}

class _SuggestFeatureScreenState extends State<SuggestFeatureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SupabaseService();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      final user = _service.currentUser;
      if (user != null) {
        await _service.submitSuggestion(
          user.id,
          _titleController.text.trim(),
          _descController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('suggestion_submitted'))),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('error_occurred'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const darkGreen = AppTheme.primary; // Official brand color

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(l10n.translate('request_feature'), 
            style: GoogleFonts.cairo(color: darkGreen, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: darkGreen),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.translate('suggest_title'), 
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: GoogleFonts.cairo(),
                decoration: InputDecoration(
                  hintText: l10n.translate('placeholder_suggest_title'),
                  prefixIcon: const Icon(Icons.title, color: darkGreen),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: darkGreen, width: 2),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? l10n.translate('required_field') : null,
              ),
              const SizedBox(height: 24),

              Text(l10n.translate('description'), 
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 5,
                style: GoogleFonts.cairo(),
                decoration: InputDecoration(
                  hintText: l10n.translate('suggest_desc'),
                  prefixIcon: const Icon(Icons.description_outlined, color: darkGreen),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: darkGreen, width: 2),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? l10n.translate('required_field') : null,
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(l10n.translate('submit'), 
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
