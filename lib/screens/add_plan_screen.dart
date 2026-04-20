import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/crop.dart';
import '../models/category.dart';
import '../models/planting_plan.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import '../utils/validators.dart';
import 'home_screen.dart';

class AddPlanScreen extends StatefulWidget {
  const AddPlanScreen({super.key});

  @override
  State<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends State<AddPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SupabaseService();
  final _areaController = TextEditingController();
  
  Profile? _profile;
  List<Crop> _allCrops = [];
  List<Crop> _filteredCrops = [];
  List<CropCategory> _categories = [];
  List<PlantingPlan> _existingPlans = [];
  
  int? _selectedCategoryId;
  int? _selectedCropId;
  DateTime? _plantingDate;
  DateTime? _harvestDate;
  bool _isLoading = false;
  double _availableArea = 0;
  double _remainingArea = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _areaController.addListener(_updateRemainingArea);
  }

  @override
  void dispose() {
    _areaController.removeListener(_updateRemainingArea);
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
      final plans = await _service.getUserPlantingPlans(user.id);
      
      double usedArea = plans
          .where((p) => p.status == 'active')
          .fold(0, (sum, p) => sum + p.areaDonums);

      setState(() {
        _profile = profile;
        _allCrops = crops;
        _categories = categories;
        _existingPlans = plans;
        _availableArea = (profile?.landSize ?? 0) - usedArea;
        _remainingArea = _availableArea;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateRemainingArea() {
    final enteredArea = double.tryParse(_areaController.text) ?? 0;
    setState(() {
      _remainingArea = _availableArea - enteredArea;
    });
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00C897),
              onPrimary: Colors.white,
              onSurface: Color(0xFF005E4D),
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
          _harvestDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    
    if (!_formKey.currentState!.validate() || _selectedCropId == null || _plantingDate == null || _harvestDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('required_field'))),
      );
      return;
    }

    final enteredArea = double.tryParse(_areaController.text) ?? 0;
    if (enteredArea > _availableArea) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _service.currentUser;
      final avgYield = await _service.getCropAvgYield(_selectedCropId!);
      final estimatedYield = enteredArea * avgYield;

      final plan = PlantingPlan(
        farmerId: user!.id,
        cropId: _selectedCropId!,
        governorateId: _profile!.governorateId,
        areaDonums: enteredArea,
        estimatedYieldTons: estimatedYield,
        aiYieldPredicted: false,
        status: 'active',
        plantingDate: _plantingDate!,
        harvestDate: _harvestDate!,
      );

      await _service.addPlantingPlan(plan);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('plan_added_success'))),
        );
        
        // Refresh the whole app state using the global key
        homeScreenKey.currentState?.refreshApp();

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
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

    final enteredArea = double.tryParse(_areaController.text) ?? 0;
    final bool isAreaValid = enteredArea > 0 && enteredArea <= _availableArea;
    final bool canSubmit = isAreaValid && _selectedCropId != null && _plantingDate != null && _harvestDate != null && !_isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(l10n.translate('add_plan'), style: GoogleFonts.cairo(color: darkGreen, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: darkGreen),
      ),
      body: _isLoading && _profile == null 
        ? const Center(child: CircularProgressIndicator(color: primaryGreen))
        : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: darkGreen,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: darkGreen.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.translate('available_area'), style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
                        Text('${_availableArea.toStringAsFixed(1)} ${l10n.translate('dunums')}', 
                             style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    const Icon(Icons.analytics_outlined, color: Colors.white, size: 30),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              Text(l10n.translate('market_categories'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
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
                Text(l10n.translate('select_crop'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _selectedCropId,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                  items: _filteredCrops.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.emoji} ${c.getName(lang)}', style: GoogleFonts.cairo()),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedCropId = val),
                  validator: (v) => v == null ? l10n.translate('required_field') : null,
                ),
                const SizedBox(height: 20),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.translate('area_donums'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
                  if (_areaController.text.isNotEmpty)
                    Text(
                      '${l10n.translate('area_remaining')}: ${_remainingArea.toStringAsFixed(1)}',
                      style: GoogleFonts.cairo(
                        color: _remainingArea < 0 ? Colors.red : primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _areaController,
                keyboardType: TextInputType.number,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                style: GoogleFonts.cairo(),
                decoration: InputDecoration(
                  hintText: l10n.translate('placeholder_area'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  suffixText: l10n.translate('dunums'),
                  prefixIcon: const Icon(Icons.square_foot, color: primaryGreen),
                ),
                validator: (v) {
                  final basic = Validators.validateLandSize(v, l10n.translate('invalid_land_size'));
                  if (basic != null) return basic;
                  final val = double.tryParse(v!) ?? 0;
                  if (val > _availableArea) return l10n.translate('insufficient_area');
                  return null;
                },
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.translate('planting_date'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: _plantingDate == null ? Colors.grey.shade300 : primaryGreen),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 18, color: _plantingDate == null ? Colors.grey : primaryGreen),
                                const SizedBox(width: 8),
                                Expanded(child: Text(
                                  _plantingDate == null ? l10n.translate('select_date') : DateFormat('yyyy-MM-dd').format(_plantingDate!), 
                                  style: GoogleFonts.cairo(fontSize: 13),
                                )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.translate('harvest_date'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectDate(context, false),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: _harvestDate == null ? Colors.grey.shade300 : primaryGreen),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 18, color: _harvestDate == null ? Colors.grey : primaryGreen),
                                const SizedBox(width: 8),
                                Expanded(child: Text(
                                  _harvestDate == null ? l10n.translate('select_date') : DateFormat('yyyy-MM-dd').format(_harvestDate!), 
                                  style: GoogleFonts.cairo(fontSize: 13),
                                )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSubmit ? primaryGreen : Colors.grey[400],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: canSubmit ? 5 : 0,
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(l10n.translate('submit'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
