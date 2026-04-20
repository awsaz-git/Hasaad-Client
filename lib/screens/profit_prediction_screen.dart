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
import '../utils/validators.dart';

class ProfitPredictionScreen extends StatefulWidget {
  const ProfitPredictionScreen({super.key});

  @override
  State<ProfitPredictionScreen> createState() => _ProfitPredictionScreenState();
}

class _ProfitPredictionScreenState extends State<ProfitPredictionScreen> {
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
  DateTime? _harvestDate;
  bool _isLoading = false;
  bool _isPredicting = false;
  Map<String, dynamic>? _predictionResult;

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
    );
    if (picked != null) {
      setState(() {
        if (isPlanting) {
          _plantingDate = picked;
        } else {
          _harvestDate = picked;
        }
      });
    }
  }

  Future<void> _submitPrediction() async {
    final l10n = AppLocalizations.of(context)!;
    
    if (!_formKey.currentState!.validate() || 
        _selectedCropId == null || 
        _plantingDate == null || 
        _harvestDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('required_field'))),
      );
      return;
    }

    if (_harvestDate!.isBefore(_plantingDate!) || _harvestDate!.isAtSameMomentAs(_plantingDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('harvest_date_after_planting'))),
      );
      return;
    }

    final area = double.tryParse(_areaController.text) ?? 0;
    if (area <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('area_must_be_positive'))),
      );
      return;
    }

    setState(() => _isPredicting = true);
    
    try {
      final selectedCrop = _allCrops.firstWhere((c) => c.id == _selectedCropId);
      final backendUrl = dotenv.env['BACKEND_URL'];
      
      var request = http.MultipartRequest('POST', Uri.parse('$backendUrl/predict_profit'));
      
      request.fields['crop'] = selectedCrop.nameEn;
      request.fields['governorate'] = _userGov?.nameEn ?? '';
      request.fields['area_donums'] = area.toString();
      request.fields['planting_date'] = DateFormat('yyyy-MM-dd').format(_plantingDate!);
      request.fields['harvest_date'] = DateFormat('yyyy-MM-dd').format(_harvestDate!);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        setState(() {
          _predictionResult = json.decode(response.body);
          _isPredicting = false;
        });
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Prediction error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('prediction_error')), backgroundColor: Colors.red),
        );
        setState(() => _isPredicting = false);
      }
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
        title: Text(l10n.translate('profit_prediction'), style: GoogleFonts.cairo(color: darkGreen, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: darkGreen),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: primaryGreen))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_predictionResult != null) ...[
                  _buildResultCard(l10n, primaryGreen, darkGreen),
                  const SizedBox(height: 24),
                ],
                
                // Model Detail Description
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryGreen.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: primaryGreen, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.translate('profit_prediction'),
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('profit_model_detail'),
                        style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[700], height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel(l10n.translate('governorate'), darkGreen),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _userGov?.getName(lang) ?? '',
                        enabled: false,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[200],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildLabel(l10n.translate('market_categories'), darkGreen),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        decoration: InputDecoration(
                          hintText: l10n.translate('all_categories'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        items: _categories.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.emoji} ${c.getName(lang)}', style: GoogleFonts.cairo()),
                        )).toList(),
                        onChanged: _onCategoryChanged,
                      ),
                      const SizedBox(height: 20),

                      if (_selectedCategoryId != null) ...[
                        _buildLabel(l10n.translate('select_crop'), darkGreen),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _selectedCropId,
                          decoration: InputDecoration(
                            hintText: l10n.translate('select_crop'),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          items: _filteredCrops.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.emoji} ${c.getName(lang)}', style: GoogleFonts.cairo()),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedCropId = val),
                          validator: (v) => v == null ? l10n.translate('required_field') : null,
                        ),
                        const SizedBox(height: 20),
                      ],

                      _buildLabel(l10n.translate('area_donums'), darkGreen),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _areaController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: l10n.translate('placeholder_area'),
                          suffixText: l10n.translate('dunums'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          prefixIcon: const Icon(Icons.square_foot),
                        ),
                        validator: (v) => Validators.validateLandSize(v, l10n.translate('invalid_land_size')),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(child: _buildDatePicker(l10n.translate('planting_date'), _plantingDate, () => _selectDate(context, true), primaryGreen, darkGreen, l10n)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDatePicker(l10n.translate('harvest_date'), _harvestDate, () => _selectDate(context, false), primaryGreen, darkGreen, l10n)),
                        ],
                      ),

                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isPredicting ? null : _submitPrediction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: _isPredicting 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(l10n.translate('predict_profit'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
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

  Widget _buildLabel(String text, Color color) {
    return Text(text, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: color));
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap, Color primary, Color dark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, dark),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: date == null ? Colors.grey.shade300 : primary),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: date == null ? Colors.grey : primary),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  date == null ? l10n.translate('select_date') : DateFormat('yyyy-MM-dd').format(date), 
                  style: GoogleFonts.cairo(fontSize: 13),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(AppLocalizations l10n, Color primary, Color dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, primary.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text(l10n.translate('profit_result'), style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            _predictionResult?['value'] ?? '',
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${_predictionResult?['crop']} - ${_predictionResult?['area']} ${l10n.translate('dunums')}',
            style: GoogleFonts.cairo(color: Colors.white.withOpacity(0.9), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
