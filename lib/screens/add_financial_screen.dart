import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/crop.dart';
import '../models/planting_plan.dart';
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
  
  final _seedsController = TextEditingController();
  final _fertilizerController = TextEditingController();
  final _irrigationController = TextEditingController();
  final _laborController = TextEditingController();
  final _pesticidesController = TextEditingController();
  final _transportController = TextEditingController();
  final _otherController = TextEditingController();
  
  final _notesController = TextEditingController();
  
  List<PlantingPlan> _availablePlans = [];
  List<Crop> _allCrops = [];
  String? _selectedPlanId;
  bool _isLoading = true;
  bool _isSaving = false;

  double get _totalExpenses {
    double s = double.tryParse(_seedsController.text) ?? 0;
    double f = double.tryParse(_fertilizerController.text) ?? 0;
    double i = double.tryParse(_irrigationController.text) ?? 0;
    double l = double.tryParse(_laborController.text) ?? 0;
    double p = double.tryParse(_pesticidesController.text) ?? 0;
    double t = double.tryParse(_transportController.text) ?? 0;
    double o = double.tryParse(_otherController.text) ?? 0;
    return s + f + i + l + p + t + o;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    if (widget.existingFinancial != null) {
      _priceController.text = widget.existingFinancial!.sellingPricePerTon.toString();
      _seedsController.text = widget.existingFinancial!.seedCost?.toString() ?? '';
      _fertilizerController.text = widget.existingFinancial!.fertilizerCost?.toString() ?? '';
      _irrigationController.text = widget.existingFinancial!.irrigationCost?.toString() ?? '';
      _laborController.text = widget.existingFinancial!.laborCost?.toString() ?? '';
      _pesticidesController.text = widget.existingFinancial!.pesticideCost?.toString() ?? '';
      _transportController.text = widget.existingFinancial!.transportCost?.toString() ?? '';
      _otherController.text = widget.existingFinancial!.otherCost?.toString() ?? '';
      _notesController.text = widget.existingFinancial!.notes ?? '';
      _selectedPlanId = widget.existingFinancial!.plantingPlanId;
    }

    // Add listeners for live total update
    void listener() => setState(() {});
    _seedsController.addListener(listener);
    _fertilizerController.addListener(listener);
    _irrigationController.addListener(listener);
    _laborController.addListener(listener);
    _pesticidesController.addListener(listener);
    _transportController.addListener(listener);
    _otherController.addListener(listener);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _seedsController.dispose();
    _fertilizerController.dispose();
    _irrigationController.dispose();
    _laborController.dispose();
    _pesticidesController.dispose();
    _transportController.dispose();
    _otherController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = _service.currentUser;
      if (user == null) return;

      final plans = await _service.getUserPlantingPlans(user.id);
      final financials = await _service.getCropFinancials(user.id);
      final crops = await _service.getCrops();

      final existingPlanIds = financials
          .where((f) => f.plantingPlanId != null && f.id != widget.existingFinancial?.id)
          .map((f) => f.plantingPlanId!)
          .toSet();

      if (mounted) {
        setState(() {
          _allCrops = crops;
          // Filter: only show plans that are active or harvested AND don't have financials yet
          _availablePlans = plans.where((p) {
            final isEligibleStatus = p.status == 'active' || p.status == 'harvested';
            return isEligibleStatus && !existingPlanIds.contains(p.id);
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedPlanId == null) return;

    setState(() => _isSaving = true);
    try {
      final user = _service.currentUser;
      final plan = _availablePlans.firstWhere((p) => p.id == _selectedPlanId);
      
      final financial = CropFinancial(
        id: widget.existingFinancial?.id,
        farmerId: user!.id,
        cropId: plan.cropId,
        sellingPricePerTon: double.parse(_priceController.text),
        seedCost: double.tryParse(_seedsController.text),
        fertilizerCost: double.tryParse(_fertilizerController.text),
        irrigationCost: double.tryParse(_irrigationController.text),
        laborCost: double.tryParse(_laborController.text),
        pesticideCost: double.tryParse(_pesticidesController.text),
        transportCost: double.tryParse(_transportController.text),
        otherCost: double.tryParse(_otherController.text),
        notes: _notesController.text,
        plantingPlanId: _selectedPlanId,
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
    const darkGreen = AppTheme.primary;

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
            child: _availablePlans.isEmpty && widget.existingFinancial == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 100),
                      Icon(Icons.assignment_late_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        l10n.translate('no_eligible_plans'),
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
                      Text(l10n.translate('select_plan_to_record'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
                      const SizedBox(height: 12),
                      ..._availablePlans.map((plan) {
                        final crop = _allCrops.firstWhere((c) => c.id == plan.cropId, orElse: () => _allCrops.first);
                        final isSelected = _selectedPlanId == plan.id;
                        
                        return GestureDetector(
                          onTap: widget.existingFinancial != null ? null : () => setState(() => _selectedPlanId = plan.id),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? darkGreen.withOpacity(0.05) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? darkGreen : Colors.grey.shade200,
                                width: isSelected ? 2 : 1
                              ),
                              boxShadow: isSelected ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(
                                    color: isSelected ? darkGreen.withOpacity(0.1) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(crop.emoji, style: const TextStyle(fontSize: 28)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(crop.getName(lang), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(
                                        '${plan.areaDonums} ${l10n.translate('dunums')} • ${l10n.translate('harvest_date')}: ${DateFormat('yyyy-MM-dd').format(plan.harvestDate)}',
                                        style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: darkGreen),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 24),

                      Text(l10n.translate('selling_price_per_ton'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: l10n.translate('placeholder_selling_price'),
                          prefixIcon: const Icon(Icons.price_change_outlined, color: darkGreen),
                          suffixText: l10n.translate('jod'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? l10n.translate('required_field') : null,
                      ),
                      const SizedBox(height: 32),

                      // Expenses Section
                      Text(l10n.translate('expenses'), style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkGreen)),
                      const SizedBox(height: 16),
                      _buildExpenseField(l10n.translate('seeds_cost'), _seedsController, Icons.grass),
                      _buildExpenseField(l10n.translate('fertilizer_cost'), _fertilizerController, Icons.science_outlined),
                      _buildExpenseField(l10n.translate('irrigation_cost'), _irrigationController, Icons.water_drop_outlined),
                      _buildExpenseField(l10n.translate('labor_cost'), _laborController, Icons.people_outline),
                      _buildExpenseField(l10n.translate('pesticide_cost'), _pesticidesController, Icons.bug_report_outlined),
                      _buildExpenseField(l10n.translate('transport_cost'), _transportController, Icons.local_shipping_outlined),
                      _buildExpenseField(l10n.translate('other_cost'), _otherController, Icons.more_horiz),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n.translate('total_expenses_summary') ?? 'Total Expenses:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                            Text('${_totalExpenses.toStringAsFixed(2)} ${l10n.translate('jod')}', 
                                 style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(l10n.translate('description'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: l10n.translate('enter_financial_desc'),
                          prefixIcon: const Icon(Icons.note_alt_outlined, color: darkGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isSaving || _selectedPlanId == null ? null : _save,
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

  Widget _buildExpenseField(String label, TextEditingController controller, IconData icon) {
    final l10n = AppLocalizations.of(context)!;
    const darkGreen = AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: darkGreen),
          suffixText: l10n.translate('jod'),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }
}
