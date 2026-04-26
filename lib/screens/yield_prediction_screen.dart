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
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/loading_overlay.dart';

class YieldPredictionScreen extends StatefulWidget {
  const YieldPredictionScreen({super.key});

  @override
  State<YieldPredictionScreen> createState() => _YieldPredictionScreenState();
}

class _YieldPredictionScreenState extends State<YieldPredictionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SupabaseService();
  final _areaController = TextEditingController();
  
  Profile? _profile;
  Governorate? _userGov;
  List<Crop> _allCrops = [];
  List<Crop> _filteredCrops = [];
  List<CropCategory> _categories = [];
  
  int? _selectedCategoryId;
  int? _selectedCropId;
  DateTime? _plantingDate;
  DateTime? _saleDate;
  bool _pestIndicator = false;
  bool _isLoading = false;
  bool _isPredicting = false;

  final Color modelThemeColor = const Color(0xFF6C63FF); // Yield theme color (Purple)

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
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
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading initial data: $e');
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

  Future<void> _selectDate(BuildContext context, bool isPlanting) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: modelThemeColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isPlanting) {
          _plantingDate = picked;
        } else {
          _saleDate = picked;
        }
      });
    }
  }

  Future<void> _submitPrediction() async {
    final l10n = AppLocalizations.of(context)!;
    
    if (!_formKey.currentState!.validate() || 
        _selectedCropId == null || 
        _plantingDate == null || 
        _saleDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('required_field'))));
      return;
    }

    if (_saleDate!.isBefore(_plantingDate!) || _saleDate!.isAtSameMomentAs(_plantingDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('sale_date_after_planting'))));
      return;
    }

    setState(() => _isPredicting = true);
    
    try {
      final selectedCrop = _allCrops.firstWhere((c) => c.id == _selectedCropId);
      final backendUrl = dotenv.env['BACKEND_URL'];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      var request = http.MultipartRequest('POST', Uri.parse('$backendUrl/predict_yield?t=$timestamp'));
      request.fields['crop_name'] = selectedCrop.nameEn;
      request.fields['governorate'] = _userGov?.nameEn ?? '';
      request.fields['area_donums'] = _areaController.text;
      request.fields['planting_date'] = DateFormat('yyyy-MM-dd').format(_plantingDate!);
      request.fields['sale_date'] = DateFormat('yyyy-MM-dd').format(_saleDate!);
      request.fields['pest_indicator'] = _pestIndicator.toString();

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
            : errorBody['detail'].toString();
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Yield Prediction error: $e');
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
    const darkGreen = AppTheme.primary;

    String rawValue = result['value']?.toString() ?? '0';
    String numericPart = rawValue.split(' ').first;
    String formattedYield = "$numericPart ${l10n.translate('tons')}";
    final selectedCrop = _allCrops.firstWhere((c) => c.id == _selectedCropId);

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
              Text(l10n.translate('yield_result'), style: GoogleFonts.cairo(fontSize: 18, color: darkGreen, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(color: modelThemeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: modelThemeColor.withOpacity(0.2))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.grass, color: modelThemeColor, size: 36),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(formattedYield, style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.bold, color: modelThemeColor), overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),
              _buildResultRow(Icons.grass_outlined, l10n.translate('crop'), '', darkGreen, trailing: _buildCropBadge(selectedCrop, lang, darkGreen)),
              const SizedBox(height: 16),
              _buildResultRow(Icons.square_foot_outlined, l10n.translate('area_donums'), "${result['area_donums']} ${l10n.translate('dunums')}", darkGreen),
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
    const darkGreen = AppTheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: Text(l10n.translate('yield_prediction'), style: GoogleFonts.cairo(color: darkGreen, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: darkGreen)),
      body: Stack(
        children: [
          _isLoading 
            ? const Center(child: CircularProgressIndicator(color: darkGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildInfoCard(l10n.translate('yield_prediction'), l10n.translate('yield_model_detail'), modelThemeColor, darkGreen),
                  const SizedBox(height: 30),
                  Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildLabel(l10n.translate('governorate'), darkGreen),
                    const SizedBox(height: 8),
                    _buildReadonlyField(_userGov?.getName(lang) ?? '', Icons.location_on_outlined),
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
                    _buildLabel(l10n.translate('area_donums'), darkGreen),
                    const SizedBox(height: 8),
                    _buildTextField(_areaController, l10n.translate('placeholder_area'), l10n.translate('dunums'), Icons.square_foot, (v) => Validators.validateLandSize(v, l10n.translate('invalid_land_size'))),
                    const SizedBox(height: 20),
                    
                    Row(children: [
                      Expanded(child: _buildDatePicker(l10n.translate('planting_date'), _plantingDate, () => _selectDate(context, true), modelThemeColor, darkGreen, l10n)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDatePicker(l10n.translate('sale_date'), _saleDate, () => _selectDate(context, false), modelThemeColor, darkGreen, l10n)),
                    ]),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.translate('pest_indicator'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(l10n.translate('pest_indicator_desc'), style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                          Switch(
                            value: _pestIndicator,
                            onChanged: (val) => setState(() => _pestIndicator = val),
                            activeColor: modelThemeColor,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                    _buildSubmitButton(l10n.translate('predict_yield'), modelThemeColor),
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
  
  Widget _buildTextField(TextEditingController controller, String hint, String suffix, IconData icon, String? Function(String?)? validator) => TextFormField(
    controller: controller, 
    keyboardType: TextInputType.number, 
    style: GoogleFonts.cairo(), 
    decoration: InputDecoration(
      hintText: hint, 
      suffixText: suffix, 
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), 
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: modelThemeColor, width: 2)),
      prefixIcon: Icon(icon, color: modelThemeColor)
    ), 
    validator: validator
  );

  Widget _buildCategoryDropdown(String lang, AppLocalizations l10n) => DropdownButtonFormField<int>(
    value: _selectedCategoryId, 
    style: GoogleFonts.cairo(color: Colors.black), 
    decoration: InputDecoration(
      hintText: l10n.translate('all_categories'), 
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), 
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: modelThemeColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
    ), 
    items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.emoji} ${c.getName(lang)}', style: GoogleFonts.cairo()))).toList(), 
    onChanged: _onCategoryChanged
  );

  Widget _buildCropDropdown(String lang, AppLocalizations l10n) => DropdownButtonFormField<int>(
    value: _selectedCropId, 
    style: GoogleFonts.cairo(color: Colors.black), 
    decoration: InputDecoration(
      hintText: l10n.translate('select_crop'), 
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), 
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: modelThemeColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
    ), 
    items: _filteredCrops.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.emoji} ${c.getName(lang)}', style: GoogleFonts.cairo()))).toList(), 
    onChanged: (val) => setState(() => _selectedCropId = val), 
    validator: (v) => v == null ? l10n.translate('required_field') : null
  );

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap, Color primary, Color dark, AppLocalizations l10n) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _buildLabel(label, dark), const SizedBox(height: 8),
    InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: date == null ? Colors.grey.shade300 : primary, width: date == null ? 1 : 2), borderRadius: BorderRadius.circular(15)), child: Row(children: [Icon(Icons.calendar_today, size: 18, color: date == null ? Colors.grey : primary), const SizedBox(width: 8), Expanded(child: Text(date == null ? l10n.translate('select_date') : DateFormat('yyyy-MM-dd').format(date), style: GoogleFonts.cairo(fontSize: 13)))]))),
  ]);

  Widget _buildSubmitButton(String text, Color color) => SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _isPredicting ? null : _submitPrediction, style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0), child: Text(text, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))));
}
