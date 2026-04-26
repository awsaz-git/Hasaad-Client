import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_localizations.dart';

class ComingSoonPredictionScreen extends StatelessWidget {
  final String titleKey;
  final String detailKey;

  const ComingSoonPredictionScreen({
    super.key,
    required this.titleKey,
    required this.detailKey,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const darkGreen = Color(0xFF005E4D);
    const primaryGreen = Color(0xFF00C897);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(l10n.translate(titleKey), style: GoogleFonts.cairo(color: darkGreen, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: darkGreen),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome, size: 60, color: primaryGreen),
                  const SizedBox(height: 16),
                  Text(
                    l10n.translate('coming_soon'),
                    style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: darkGreen),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.translate(detailKey),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[600], height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Mock form UI to show "how it will be"
            Opacity(
              opacity: 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMockField(l10n.translate('select_crop')),
                  const SizedBox(height: 20),
                  _buildMockField(l10n.translate('area_donums')),
                  const SizedBox(height: 20),
                  _buildMockField(l10n.translate('planting_date')),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.translate('submit'),
                      style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockField(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.grey[700])),
        const SizedBox(height: 8),
        Container(
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}
