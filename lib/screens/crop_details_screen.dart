import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/crop.dart';
import '../models/crop_demand.dart';
import '../models/crop_supply.dart';
import '../models/governorate.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';

class CropDetailsScreen extends StatefulWidget {
  final Crop crop;
  const CropDetailsScreen({super.key, required this.crop});

  @override
  State<CropDetailsScreen> createState() => _CropDetailsScreenState();
}

class _CropDetailsScreenState extends State<CropDetailsScreen> {
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
      
      setState(() {
        _demand = demand;
        _supplies = supplies;
        _governorates = govs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    const darkGreen = Color(0xFF005E4D);
    const primaryGreen = Color(0xFF00C897);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.crop.emoji} ${widget.crop.getName(lang)}', 
            style: GoogleFonts.cairo(color: darkGreen, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkGreen),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Market Demand Section
                  _buildSectionTitle(l10n.translate('total_demand'), darkGreen),
                  const SizedBox(height: 8),
                  Text(
                    '${_demand?.demandTons.toInt() ?? 0} ${l10n.translate('tons')}',
                    style: GoogleFonts.cairo(fontSize: 32, fontWeight: FontWeight.bold, color: primaryGreen),
                  ),
                  const SizedBox(height: 24),

                  // Market Notes
                  _buildSectionTitle(l10n.translate('market_notes'), darkGreen),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      _demand?.getNotes(lang) ?? l10n.translate('no_notes'),
                      style: GoogleFonts.cairo(color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Supply by Governorate
                  _buildSectionTitle(l10n.translate('supply_by_governorate'), darkGreen),
                  const SizedBox(height: 16),
                  ..._supplies.map((s) {
                    final gov = _governorates.firstWhere((g) => g.id == s.governorateId, 
                        orElse: () => Governorate(id: 0, nameEn: 'Unknown', nameAr: 'غير معروف'));
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(gov.getName(lang), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          Text('${s.totalEstimatedTons.toInt()} ${l10n.translate('tons')}', 
                              style: GoogleFonts.cairo(color: primaryGreen, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: color),
    );
  }
}
