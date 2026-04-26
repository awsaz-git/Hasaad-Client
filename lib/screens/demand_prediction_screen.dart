import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/crop.dart';
import '../models/category.dart';
import '../models/governorate.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import '../widgets/loading_overlay.dart';

class DemandPredictionScreen extends StatefulWidget {
  const DemandPredictionScreen({super.key});

  @override
  State<DemandPredictionScreen> createState() => _DemandPredictionScreenState();
}

class _DemandPredictionScreenState extends State<DemandPredictionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SupabaseService();
  
  Profile? _profile;
  Governorate? _userGov;
  List<Crop> _allCrops = [];
  List<Crop> _filteredCrops = [];
  List<CropCategory> _categories = [];
  List<Governorate> _governorates = [];
  
  int? _selectedMarketGovId;
  int? _selectedCategoryId;
  int? _selectedCropId;
  DateTime? _predictionDate;
  bool _isLoading = false;
  bool _isPredicting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final user = _service.currentUser;
      final profile = await _service.getProfile(user!.id);
      final crops = await _service.getCrops();
      final categories = await _service.getCategories();
      final govs = await _service.getGovernorates();
      
      Governorate? myGov;
      if (profile != null) {
        myGov = govs.firstWhere((g) => g.id == profile.governorateId);
      }

      setState(() {
        _profile = profile;
        _userGov = myGov;
        _allCrops = crops;
        _categories = categories;
        _governorates = govs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onCategoryChanged(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      if (categoryId == null) {
        _filteredCrops = [];
      } else {
        _filteredCrops = _allCrops.where((c) => c.categoryId == categoryId).toList();
      }
      _selectedCropId = null; 
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _predictionDate = picked;
      });
    }
  }

  String _mapGovernorateToMarket(String govEn) {
    final ammanMarkets = ["Amman", "Madaba", "Balqa"];
    final zarqaMarkets = ["Zarqa", "Mafraq"];
    final irbidMarkets = ["Irbid", "Jarash", "Ajloun"];
    final aqabaMarkets = ["Aqaba", "Ma'an", "Karak", "Tafilah"];

    if (ammanMarkets.contains(govEn)) return "Amman";
    if (zarqaMarkets.contains(govEn)) return "Zarqa";
    if (irbidMarkets.contains(govEn)) return "Irbid";
    if (aqabaMarkets.contains(govEn)) return "Aqaba";
    return "Other";
  }

  Future<void> _submitPrediction() async {
    final l10n = AppLocalizations.of(context)!;
    
    if (!_formKey.currentState!.validate() || _selectedCropId == null || _selectedMarketGovId == null || _predictionDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('required_field'))));
      return;
    }

    setState(() => _isPredicting = true);
    
    try {
      final selectedCrop = _allCrops.firstWhere((c) => c.id == _selectedCropId);
      final marketGov = _governorates.firstWhere((g) => g.id == _selectedMarketGovId);
      final backendUrl = dotenv.env['BACKEND_URL'];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      var request = http.MultipartRequest('POST', Uri.parse('$backendUrl/predict_demand?t=$timestamp'));
      request.fields['crop_name'] = selectedCrop.nameEn;
      request.fields['market_location'] = _mapGovernorateToMarket(marketGov.nameEn);
      request.fields['sale_date'] = DateFormat('yyyy-MM-dd').format(_predictionDate!);
      if (_userGov != null) {
        request.fields['governorate'] = _userGov!.nameEn;
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        setState(() => _isPredicting = false);
        if (mounted) _showResultOverlay(result);
      } else {
        final errorBody = json.decode(response.body);
        String errorMessage = errorBody['detail'] is List 
            ? (errorBody['detail'] as List).map((e) => e['msg']).join(', ')
            : errorBody['detail']?.toString() ?? 'Prediction failed';
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Demand Prediction error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
        setState(() => _isPredicting = false);
      }
    }
  }

  void _showResultOverlay(Map<String, dynamic> result) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    const primaryYellow = Color(0xFFF7B731);
    const darkGreen = Color(0xFF005E4D);

    String demandLevel = result['value']?.toString().toLowerCase() ?? 'medium';
    Color levelColor;
    IconData levelIcon;
    
    if (demandLevel == 'high') {
      levelColor = Colors.green;
      levelIcon = Icons.trending_up;
    } else if (demandLevel == 'low') {
      levelColor = Colors.red;
      levelIcon = Icons.trending_down;
    } else {
      levelColor = primaryYellow;
      levelIcon = Icons.trending_flat;
    }

    final selectedCrop = _allCrops.firstWhere((c) => c.id == _selectedCropId);
    final marketGov = _governorates.firstWhere((g) => g.id == _selectedMarketGovId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text(l10n.translate('demand_result'), style: GoogleFonts.cairo(fontSize: 18, color: darkGreen, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(color: levelColor.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: levelColor.withOpacity(0.2))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(levelIcon, color: levelColor, size: 36),
                  const SizedBox(width: 16),
                  Text(l10n.translate(demandLevel).toUpperCase(), style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.bold, color: levelColor)),
                ]),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),
              _buildResultRow(Icons.grass_outlined, l10n.translate('crop'), '', darkGreen, trailing: _buildCropBadge(selectedCrop, lang, darkGreen)),
              const SizedBox(height: 16),
              _buildResultRow(Icons.shopping_cart_outlined, l10n.translate('market_location'), marketGov.getName(lang), darkGreen),
              const SizedBox(height: 16),
              _buildResultRow(Icons.calendar_today_outlined, l10n.translate('demand_date_label'), DateFormat('yyyy-MM-dd').format(_predictionDate!), darkGreen),
              const SizedBox(height: 40),
              SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: darkGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 0), child: Text(l10n.translate('confirm'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)))),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCropBadge(Crop crop, String lang, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(crop.emoji, style: const TextStyle(fontSize: 18)), const SizedBox(width: 8), Text(crop.getName(lang), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: color, fontSize: 14))]));

  Widget _buildResultRow(IconData icon, String label, String value, Color color, {Widget? trailing}) => Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.05), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)), const SizedBox(width: 16), Text(label, style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 14)), const Spacer(), trailing ?? Text(value, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16))]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    const darkGreen = Color(0xFF005E4D);
    const primaryYellow = Color(0xFFF7B731);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: Text(l10n.translate('demand_prediction'), style: GoogleFonts.cairo(color: darkGreen, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: darkGreen)),
      body: Stack(
        children: [
          _isLoading 
            ? const Center(child: CircularProgressIndicator(color: primaryYellow))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildInfoCard(l10n.translate('demand_prediction'), l10n.translate('demand_model_detail'), primaryYellow, darkGreen),
                  const SizedBox(height: 30),
                  Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildLabel(l10n.translate('governorate'), darkGreen),
                    const SizedBox(height: 8),
                    _buildReadonlyField(_userGov?.getName(lang) ?? '', Icons.location_on_outlined),
                    const SizedBox(height: 20),

                    _buildLabel(l10n.translate('market_location'), darkGreen),
                    const SizedBox(height: 8),
                    _buildMarketDropdown(lang, l10n),
                    const SizedBox(height: 20),

                    _buildLabel(l10n.translate('market_categories'), darkGreen),
                    const SizedBox(height: 8),
                    _buildCategoryDropdown(lang, l10n),
                    const SizedBox(height: 20),

                    if (_selectedCategoryId != null) ...[
                      _buildLabel(l10n.translate('select_crop'), darkGreen),
                      const SizedBox(height: 8),
                      _buildCropDropdown(lang, l10n),
                      const SizedBox(height: 20),
                    ],

                    _buildLabel(l10n.translate('demand_date_label'), darkGreen),
                    const SizedBox(height: 8),
                    _buildDatePicker(_predictionDate, () => _selectDate(context), primaryYellow, darkGreen, l10n),

                    const SizedBox(height: 40),
                    _buildSubmitButton(l10n.translate('predict_demand'), primaryYellow),
                    const SizedBox(height: 40),
                  ])),
                ]),
              ),
          if (_isPredicting) const LoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String detail, Color primary, Color dark) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: primary.withOpacity(0.1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.info_outline, color: primary, size: 20), const SizedBox(width: 8), Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: dark))]), const SizedBox(height: 8), Text(detail, style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[700], height: 1.5))]));
  Widget _buildLabel(String text, Color color) => Text(text, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: color, fontSize: 14));
  Widget _buildReadonlyField(String value, IconData icon) => TextFormField(initialValue: value, enabled: false, style: GoogleFonts.cairo(), decoration: InputDecoration(filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none), prefixIcon: Icon(icon)));
  Widget _buildCategoryDropdown(String lang, AppLocalizations l10n) => DropdownButtonFormField<int>(value: _selectedCategoryId, style: GoogleFonts.cairo(color: Colors.black), decoration: InputDecoration(hintText: l10n.translate('all_categories'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.emoji} ${c.getName(lang)}', style: GoogleFonts.cairo()))).toList(), onChanged: _onCategoryChanged);
  Widget _buildCropDropdown(String lang, AppLocalizations l10n) => DropdownButtonFormField<int>(value: _selectedCropId, style: GoogleFonts.cairo(color: Colors.black), decoration: InputDecoration(hintText: l10n.translate('select_crop'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), items: _filteredCrops.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.emoji} ${c.getName(lang)}', style: GoogleFonts.cairo()))).toList(), onChanged: (val) => setState(() => _selectedCropId = val), validator: (v) => v == null ? l10n.translate('required_field') : null);
  
  Widget _buildMarketDropdown(String lang, AppLocalizations l10n) => DropdownButtonFormField<int>(
    value: _selectedMarketGovId, 
    style: GoogleFonts.cairo(color: Colors.black), 
    decoration: InputDecoration(
      hintText: l10n.translate('select_market'), 
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), 
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
    ), 
    items: _governorates.map((g) => DropdownMenuItem(value: g.id, child: Text(g.getName(lang), style: GoogleFonts.cairo()))).toList(), 
    onChanged: (val) => setState(() => _selectedMarketGovId = val), 
    validator: (v) => v == null ? l10n.translate('required_field') : null
  );

  Widget _buildDatePicker(DateTime? date, VoidCallback onTap, Color primary, Color dark, AppLocalizations l10n) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: date == null ? Colors.grey.shade300 : primary), borderRadius: BorderRadius.circular(15)), child: Row(children: [Icon(Icons.calendar_today, size: 18, color: date == null ? Colors.grey : primary), const SizedBox(width: 8), Expanded(child: Text(date == null ? l10n.translate('select_date') : DateFormat('yyyy-MM-dd').format(date), style: GoogleFonts.cairo(fontSize: 13)))])));
  Widget _buildSubmitButton(String text, Color color) => SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _isPredicting ? null : _submitPrediction, style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0), child: Text(text, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))));
}
