import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/crop.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';
import 'crop_details_overlay.dart';

class CropCard extends StatelessWidget {
  final Crop crop;
  final double supply;
  final double demand;

  const CropCard({
    super.key,
    required this.crop,
    required this.supply,
    required this.demand,
  });

  Color _getRatioColor(double ratio) {
    if (ratio <= 40) return AppTheme.primary;
    if (ratio <= 75) return const Color(0xFF8BC34A);
    if (ratio <= 90) return const Color(0xFFFFC107);
    if (ratio <= 100) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _getStatusLabelKey(double ratio) {
    if (ratio <= 75) return 'good_opportunity';
    if (ratio <= 90) return 'fair_opportunity';
    return 'oversupply';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    const darkGreen = AppTheme.primary;

    final ratio = demand > 0 ? (supply / demand) * 100 : 0.0;
    final statusColor = _getRatioColor(ratio);
    final statusLabelKey = _getStatusLabelKey(ratio);

    return GestureDetector(
      onTap: () => CropDetailsOverlay.show(context, crop, supply, demand),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9F4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(crop.emoji, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crop.getName(lang),
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: darkGreen,
                        ),
                      ),
                      Text(
                        l10n.translate(statusLabelKey),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${ratio.toInt()}%',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      l10n.translate('self_sufficiency'),
                      style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (ratio / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetric(l10n.translate('supply'), supply, l10n),
                _buildMetric(l10n.translate('demand'), demand, l10n),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, double value, AppLocalizations l10n) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
        ),
        Text(
          '${value.toInt()} ${l10n.translate('tons')}',
          style: GoogleFonts.cairo(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
