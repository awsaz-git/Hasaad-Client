import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/crop.dart';
import '../models/category.dart';
import '../models/crop_financial.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';

class AddFinancialScreen extends StatefulWidget {
  final CropFinancial? existingFinancial;
  const AddFinancialScreen({super.key, this.existingFinancial});

  @override
  State<AddFinancialScreen> createState() => _AddFinancialScreenState();
}

class _AddFinancialScreenState extends State<AddFinancialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SupabaseService();
  final _priceController = TextEditingController();
  final _expensesController = TextEditingController();
  final _notesController = TextEditingController();
  
  List<Crop> _allCrops = [];
  List<Crop> _filteredCrops = [];
  List<CropCategory> _categories = [];
  int? _selectedCategoryId;
  int? _selectedCropId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    if (widget.existingFinancial != null) {
      _priceController.text = widget.existingFinancial!.sellingPricePerTon.toString();
      _expensesController.text = widget.existingFinancial!.totalExpenses.toString();
      _notesController.text = widget.existingFinancial!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _expensesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = _service.currentUser;
      if (user == null) return;

      // 1. Fetch user's plans to see which crops they have
      final plans = await _service.getUserPlantingPlans(user.id);
      final myCropIds = plans.map((p) => p.cropId).toSet();

      // 2. Fetch all crops and categories
      final allCrops = await _service.getCrops();
      final allCategories = await _service.getCategories();
      
      if (mounted) {
        setState(() {
          // 3. Filter crops to only include those in user's plans
          _allCrops = allCrops.where((c) => myCropIds.contains(c.id)).toList();
          
          // 4. Filter categories to only include those that have the relevant crops
          final myCategoryIds = _allCrops.map((c) => c.categoryId).toSet();
          _categories = allCategories.where((cat) => myCategoryIds.contains(cat.id)).toList();
          
          if (widget.existingFinancial != null) {
            _selectedCropId = widget.existingFinancial!.cropId;
            final crop = allCrops.firstWhere((c) => c.id == _selectedCropId);
            _selectedCategoryId = crop.categoryId;
            _filteredCrops = _allCrops.where((c) => c.categoryId == _selectedCategoryId).toList();
          }
          
          _isLoading = false;
        });
      }
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedCropId == null) return;

    setState(() => _isSaving = true);
    try {
      final user = _service.currentUser;
      final financial = CropFinancial(
        farmerId: user!.id,
        cropId: _selectedCropId!,
        sellingPricePerTon: double.parse(_priceController.text),
        totalExpenses: double.parse(_expensesController.text),
        notes: _notesController.text,
      );

      await _service.upsertCropFinancial(financial);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    const darkGreen = AppTheme.primary; // Official brand color

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingFinancial == null 
            ? l10n.translate('add_financial_data') 
            : l10n.translate('edit_financial_data'),
          style: GoogleFonts.cairo(color: darkGreen, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkGreen),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: darkGreen))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _categories.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 100),
                      Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        l10n.translate('no_plans_financial_hint') ?? 'Add a planting plan first to record financial data.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.translate('market_categories'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        decoration: InputDecoration(
                          hintText: l10n.translate('all_categories'),
                          prefixIcon: const Icon(Icons.category_outlined, color: darkGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: darkGreen, width: 2),
                          ),
                        ),
                        items: _categories.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.emoji} ${c.getName(lang)}', style: GoogleFonts.cairo()),
                        )).toList(),
                        onChanged: widget.existingFinancial == null ? _onCategoryChanged : null,
                      ),
                      const SizedBox(height: 24),

                      if (_selectedCategoryId != null) ...[
                        Text(l10n.translate('select_crop'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _selectedCropId,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.grass_outlined, color: darkGreen),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: darkGreen, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          items: _filteredCrops.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.emoji} ${c.getName(lang)}'),
                          )).toList(),
                          onChanged: widget.existingFinancial == null 
                            ? (val) => setState(() => _selectedCropId = val)
                            : null,
                          validator: (v) => v == null ? l10n.translate('required_field') : null,
                        ),
                        const SizedBox(height: 24),
                      ],

                      Text(l10n.translate('selling_price_per_ton'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.cairo(),
                        decoration: InputDecoration(
                          hintText: l10n.translate('placeholder_selling_price'),
                          prefixIcon: const Icon(Icons.price_change_outlined, color: darkGreen),
                          suffixText: l10n.translate('jod'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: darkGreen, width: 2),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty ? l10n.translate('required_field') : null,
                      ),
                      const SizedBox(height: 24),

                      Text(l10n.translate('total_expenses'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _expensesController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.cairo(),
                        decoration: InputDecoration(
                          hintText: l10n.translate('placeholder_total_expenses'),
                          prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: darkGreen),
                          suffixText: l10n.translate('jod'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: darkGreen, width: 2),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty ? l10n.translate('required_field') : null,
                      ),
                      const SizedBox(height: 24),

                      Text(l10n.translate('description'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        style: GoogleFonts.cairo(),
                        decoration: InputDecoration(
                          hintText: l10n.translate('enter_financial_desc'),
                          prefixIcon: const Icon(Icons.note_alt_outlined, color: darkGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: darkGreen, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: _isSaving 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(l10n.translate('submit'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }
}
