import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import 'login_screen.dart';
import 'suggest_feature_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Function(Locale) onLanguageChange;
  const ProfileScreen({super.key, required this.onLanguageChange});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = SupabaseService();
  Profile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _service.currentUser;
    if (user != null) {
      final profile = await _service.getProfile(user.id);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    }
  }

  void _shareApp() {
    final l10n = AppLocalizations.of(context)!;
    Share.share(l10n.translate('share_message'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    const darkGreen = Color(0xFF015E54);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('profile'), style: GoogleFonts.cairo(color: darkGreen, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextButton(
              onPressed: () {
                widget.onLanguageChange(isAr ? const Locale('en') : const Locale('ar'));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: darkGreen.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  isAr ? '🇬🇧 EN' : '🇯🇴 عربي',
                  style: GoogleFonts.cairo(color: darkGreen, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: darkGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: darkGreen,
                    child: Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  _buildInfoCard(l10n),
                  const SizedBox(height: 24),
                  
                  // Suggestion Feature Section
                  _buildMenuCard(
                    l10n.translate('request_feature'),
                    Icons.lightbulb_outline,
                    Colors.orangeAccent, // Changed to Yellow/Gold for consistency
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuggestFeatureScreen())),
                  ),
                  const SizedBox(height: 16),
                  
                  // Share App Section
                  _buildMenuCard(
                    l10n.translate('share_app'),
                    Icons.share_outlined,
                    Colors.blue,
                    _shareApp,
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _service.signOut();
                        if (mounted) {
                          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => LoginScreen(onLanguageChange: widget.onLanguageChange),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: Text(l10n.translate('sign_out'), style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMenuCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          _infoRow(Icons.badge_outlined, l10n.translate('national_id'), _profile?.nationalId ?? ''),
          const Divider(height: 32),
          _infoRow(Icons.person_outline, l10n.translate('full_name'), _profile?.fullName ?? ''),
          const Divider(height: 32),
          _infoRow(Icons.square_foot_outlined, l10n.translate('land_size'), '${_profile?.landSize} ${l10n.translate('dunums')}'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 24),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12)),
            Text(value, style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ],
    );
  }
}
