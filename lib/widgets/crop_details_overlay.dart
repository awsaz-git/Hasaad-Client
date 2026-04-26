import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/crop.dart';
import '../models/crop_demand.dart';
import '../models/crop_supply.dart';
import '../models/governorate.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';

class CropDetailsOverlay extends StatefulWidget {
  final Crop crop;
  const CropDetailsOverlay({super.key, required this.crop});

  static void show(BuildContext context, Crop crop, double supply, double demand) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CropDetailsOverlay(crop: crop),
    );
  }

  @override
  State<CropDetailsOverlay> createState() => _CropDetailsOverlayState();
}

class _CropDetailsOverlayState extends State<CropDetailsOverlay> {
  final _service = SupabaseService();
  bool _isLoading = true;
  CropDemand? _demand;
  List<CropSupply> _supplies = [];
  List<Governorate> _governorates = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final demand = await _service.getCropDemand(widget.crop.id);
      final supplies = await _service.getDetailedCropSupply(widget.crop.id);
      final govs = await _service.getGovernorates();
      
      if (mounted) {
        setState(() {
          _demand = demand;
          _supplies = supplies;
          _governorates = govs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

    final totalLocalSupply = _supplies.fold(0.0, (sum, s) => sum + s.totalEstimatedTons);
    final demandTons = _demand?.demandTons ?? 0;
    final ratio = demandTons > 0 ? (totalLocalSupply / demandTons) * 100 : 0.0;
    final statusColor = _getRatioColor(ratio);
    final statusLabelKey = _getStatusLabelKey(ratio);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: darkGreen.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(widget.crop.emoji, style: const TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.crop.getName(lang),
                        style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: darkGreen),
                      ),
                      Text(
                        l10n.translate(statusLabelKey),
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSummaryStat(l10n.translate('self_sufficiency'), '${ratio.toInt()}%', statusColor),
                        _buildSummaryStat(l10n.translate('expected_supply'), '${totalLocalSupply.toInt()} ${l10n.translate('tons')}', statusColor),
                        _buildSummaryStat(l10n.translate('total_demand'), '${demandTons.toInt()} ${l10n.translate('tons')}', darkGreen),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (ratio / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              Text(l10n.translate('market_notes'), style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkGreen)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  _demand?.getNotes(lang) ?? l10n.translate('no_notes'),
                  style: GoogleFonts.cairo(color: Colors.black87, height: 1.6),
                ),
              ),
              const SizedBox(height: 32),
              
              Text(l10n.translate('supply_by_governorate'), style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkGreen)),
              const SizedBox(height: 16),
              if (_supplies.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l10n.translate('no_supply_data'), style: GoogleFonts.cairo(color: Colors.grey)),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _supplies.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = _supplies[index];
                    final gov = _governorates.firstWhere((g) => g.id == s.governorateId, orElse: () => Governorate(id: 0, nameEn: 'Unknown', nameAr: 'غير معروف'));
                    final govRatio = demandTons > 0 ? (s.totalEstimatedTons / demandTons) : 0.0;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(gov.getName(lang), style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: govRatio.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade100,
                                valueColor: AlwaysStoppedAnimation<Color>(statusColor.withValues(alpha: 0.6)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${s.totalEstimatedTons.toInt()} ${l10n.translate('tons')}',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
