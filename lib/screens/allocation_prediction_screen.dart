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

class AllocationPredictionScreen extends StatefulWidget {
  const AllocationPredictionScreen({super.key});

  @override
  State<AllocationPredictionScreen> createState() => _AllocationPredictionScreenState();
}

class _AllocationPredictionScreenState extends State<AllocationPredictionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SupabaseService();
  final _areaController = TextEditingController();
  
  Profile? _profile;
  Governorate? _userGov;
  List<Crop> _allCrops = [];
  List<CropCategory> _categories = [];
  List<Crop> _selectedCrops = [];
  
  int? _activeCategoryId;
  DateTime? _plantingDate;
  DateTime? _saleDate;
  bool _isLoading = false;
  bool _isPredicting = false;
  
  String _sortBy = 'none';

  final Color modelThemeColor = AppTheme.primary; // Allocation theme color (Dark Green)

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
      final cats = await _service.getCategories();
      final govs = await _service.getGovernorates();
      
      Governorate? myGov;
      if (profile != null) {
        myGov = govs.firstWhere((g) => g.id == profile.governorateId);
      }

      setState(() {
        _profile = profile;
        _userGov = myGov;
        _allCrops = crops;
        _categories = cats;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isPlanting) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
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

  void _showCropSelectionDialog() {
    final lang = Localizations.localeOf(context).languageCode;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredCrops = _activeCategoryId == null 
                ? _allCrops 
                : _allCrops.where((c) => c.categoryId == _activeCategoryId).toList();

            return AlertDialog(
              title: Text(AppLocalizations.of(context)!.translate('select_crops'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: modelThemeColor)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text(AppLocalizations.of(context)!.translate('all_categories'), style: GoogleFonts.cairo(fontSize: 12)),
                            selected: _activeCategoryId == null,
                            selectedColor: modelThemeColor.withOpacity(0.2),
                            onSelected: (selected) {
                              setDialogState(() => _activeCategoryId = null);
                            },
                          ),
                          const SizedBox(width: 8),
                          ..._categories.map((cat) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(cat.getName(lang), style: GoogleFonts.cairo(fontSize: 12)),
                              selected: _activeCategoryId == cat.id,
                              selectedColor: modelThemeColor.withOpacity(0.2),
                              onSelected: (selected) {
                                setDialogState(() => _activeCategoryId = selected ? cat.id : null);
                              },
                            ),
                          )),
                        ],
                      ),
                    ),
                    const Divider(),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredCrops.length,
                        itemBuilder: (context, index) {
                          final crop = filteredCrops[index];
                          final isSelected = _selectedCrops.any((c) => c.id == crop.id);
                          return CheckboxListTile(
                            activeColor: modelThemeColor,
                            title: Text('${crop.emoji} ${crop.getName(lang)}', style: GoogleFonts.cairo()),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  _selectedCrops.add(crop);
                                } else {
                                  _selectedCrops.removeWhere((c) => c.id == crop.id);
                                }
                              });
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.translate('confirm'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: modelThemeColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitPrediction() async {
    final l10n = AppLocalizations.of(context)!;
    
    if (!_formKey.currentState!.validate() || _selectedCrops.isEmpty || _plantingDate == null || _saleDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('required_field'))));
      return;
    }

    if (_saleDate!.isBefore(_plantingDate!) || _saleDate!.isAtSameMomentAs(_plantingDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('sale_date_after_planting'))));
      return;
    }

    setState(() => _isPredicting = true);
    
    try {
      final backendUrl = dotenv.env['BACKEND_URL'];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cropsList = _selectedCrops.map((c) => c.nameEn).join(',');
      
      var request = http.MultipartRequest('POST', Uri.parse('$backendUrl/predict_optimization?t=$timestamp'));
      request.fields['governorate'] = _userGov?.nameEn ?? '';
      request.fields['area_donums'] = _areaController.text;
      request.fields['planting_date'] = DateFormat('yyyy-MM-dd').format(_plantingDate!);
      request.fields['sale_date'] = DateFormat('yyyy-MM-dd').format(_saleDate!);
      request.fields['crops_list'] = cropsList;

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
      debugPrint('Optimization Prediction error: $e');
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

    Map<String, dynamic> rawAllocations = {};
    if (result['crop_allocation'] is Map) {
      rawAllocations = Map<String, dynamic>.from(result['crop_allocation']);
    } else if (result['allocations'] is Map) {
      rawAllocations = Map<String, dynamic>.from(result['allocations']);
    }

    double totalProfit = (result['expected_total_profit'] as num?)?.toDouble() ?? 
                       (result['total_profit'] as num?)?.toDouble() ?? 0.0;
    
    double totalFarmArea = (result['total_farm_area_donums'] as num?)?.toDouble() ?? 
                         (double.tryParse(_areaController.text) ?? 1.0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          List<MapEntry<String, dynamic>> allocations = rawAllocations.entries.toList();
          
          if (_sortBy == 'area') {
            allocations.sort((a, b) {
              double valA = (a.value is Map ? (a.value['area_donums'] ?? 0) : a.value) as double;
              double valB = (b.value is Map ? (b.value['area_donums'] ?? 0) : b.value) as double;
              return valB.compareTo(valA);
            });
          } else if (_sortBy == 'share') {
            allocations.sort((a, b) {
              double valA = (a.value is Map ? (a.value['area_donums'] ?? 0) : a.value) as double;
              double valB = (b.value is Map ? (b.value['area_donums'] ?? 0) : b.value) as double;
              return valB.compareTo(valA);
            });
          }

          return Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.translate('allocation_result'), 
                          style: GoogleFonts.cairo(fontSize: 18, color: darkGreen, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildSortButton(l10n, darkGreen, (val) => setModalState(() => _sortBy = val)),
                    ],
                  ),
                  if (_sortBy != 'none')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Chip(
                        label: Text(
                          '${l10n.translate('filter')}: ${l10n.translate('sort_' + _sortBy)}',
                          style: GoogleFonts.cairo(fontSize: 11, color: darkGreen, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: darkGreen.withValues(alpha: 0.1),
                        deleteIcon: const Icon(Icons.close, size: 14, color: darkGreen),
                        onDeleted: () => setModalState(() => _sortBy = 'none'),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: modelThemeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(l10n.translate('total_profit'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                      Text('${totalProfit.toStringAsFixed(2)} ${l10n.translate('jod')}', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: modelThemeColor)),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  if (allocations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(child: Text(l10n.translate('no_data'), style: GoogleFonts.cairo())),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: allocations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        String cropNameEn = allocations[index].key;
                        var cropValue = allocations[index].value;
                        
                        double areaDonums = 0.0;
                        if (cropValue is Map) {
                          if (cropValue.containsKey('area_donums')) {
                            areaDonums = (cropValue['area_donums'] as num).toDouble();
                          } else if (cropValue.containsKey('area_hectares')) {
                            areaDonums = (cropValue['area_hectares'] as num).toDouble() * 10.0;
                          }
                        } else if (cropValue is num) {
                          areaDonums = cropValue.toDouble() * 10.0;
                        }
                        
                        final crop = _allCrops.firstWhere(
                          (c) => c.nameEn.toLowerCase() == cropNameEn.toLowerCase(),
                          orElse: () => Crop(id: 0, nameEn: cropNameEn, nameAr: cropNameEn, categoryId: 0, emoji: '🌱', avgYield: 0.0),
                        );
                        
                        double share = totalFarmArea > 0 ? (areaDonums / totalFarmArea) * 100 : 0;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(15)),
                          child: Row(children: [
                            Text(crop.emoji, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(crop.getName(lang), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                Text('${areaDonums.toStringAsFixed(1)} ${l10n.translate('dunums')}', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: modelThemeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Text('${share.toStringAsFixed(0)}%', style: GoogleFonts.cairo(color: modelThemeColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ]),
                        );
                      },
                    ),
                  const SizedBox(height: 32),
                  SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: darkGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 0), child: Text(l10n.translate('confirm'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)))),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildSortButton(AppLocalizations l10n, Color primaryColor, Function(String) onSelected) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, color: primaryColor, size: 16),
            const SizedBox(width: 8),
            Text(
              l10n.translate('filter'),
              style: GoogleFonts.cairo(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        _buildSortItem('none', l10n.translate('none'), Icons.refresh),
        const PopupMenuDivider(),
        _buildSortItem('area', l10n.translate('sort_area'), Icons.square_foot),
        _buildSortItem('share', l10n.translate('sort_share'), Icons.pie_chart_outline),
      ],
    );
  }

  PopupMenuItem<String> _buildSortItem(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: isSelected ? const Color(0xFF00C897) : Colors.grey, size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: isSelected ? const Color(0xFF00C897) : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    const darkGreen = AppTheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: Text(l10n.translate('allocation_prediction'), style: GoogleFonts.cairo(color: darkGreen, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: darkGreen)),
      body: Stack(
        children: [
          _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildInfoCard(l10n.translate('allocation_prediction'), l10n.translate('allocation_model_detail'), modelThemeColor, darkGreen),
                  const SizedBox(height: 30),
                  Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildLabel(l10n.translate('governorate'), darkGreen),
                    const SizedBox(height: 8),
                    _buildReadonlyField(_userGov?.getName(lang) ?? '', Icons.location_on_outlined),
                    const SizedBox(height: 20),
                    _buildLabel(l10n.translate('area_donums'), darkGreen),
                    const SizedBox(height: 8),
                    _buildTextField(_areaController, l10n.translate('placeholder_area'), l10n.translate('dunums'), Icons.square_foot, (v) => Validators.validateLandSize(v, l10n.translate('invalid_land_size'))),
                    const SizedBox(height: 20),
                    _buildLabel(l10n.translate('crops_list'), darkGreen),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _showCropSelectionDialog,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _selectedCrops.isEmpty ? Colors.grey.shade300 : modelThemeColor, width: _selectedCrops.isEmpty ? 1 : 2), borderRadius: BorderRadius.circular(15)),
                        child: Row(children: [
                          Icon(Icons.list_alt, color: _selectedCrops.isEmpty ? Colors.grey : modelThemeColor),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_selectedCrops.isEmpty ? l10n.translate('select_crops') : _selectedCrops.map((c) => c.getName(lang)).join(', '), style: GoogleFonts.cairo(), overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: _buildDatePicker(l10n.translate('planting_date'), _plantingDate, () => _selectDate(context, true), modelThemeColor, darkGreen, l10n)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDatePicker(l10n.translate('sale_date'), _saleDate, () => _selectDate(context, false), modelThemeColor, darkGreen, l10n)),
                    ]),
                    const SizedBox(height: 40),
                    _buildSubmitButton(l10n.translate('predict_allocation'), modelThemeColor),
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

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap, Color primary, Color dark, AppLocalizations l10n) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _buildLabel(label, dark), const SizedBox(height: 8),
    InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: date == null ? Colors.grey.shade300 : primary, width: date == null ? 1 : 2), borderRadius: BorderRadius.circular(15)), child: Row(children: [Icon(Icons.calendar_today, size: 18, color: date == null ? Colors.grey : primary), const SizedBox(width: 8), Expanded(child: Text(date == null ? l10n.translate('select_date') : DateFormat('yyyy-MM-dd').format(date), style: GoogleFonts.cairo(fontSize: 13)))]))),
  ]);
  Widget _buildSubmitButton(String text, Color color) => SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _isPredicting ? null : _submitPrediction, style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0), child: Text(text, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))));
}
