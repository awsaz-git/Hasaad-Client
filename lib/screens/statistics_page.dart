import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/planting_plan.dart';
import '../models/crop.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';
import 'add_plan_screen.dart';
import 'home_screen.dart';
import 'financial_screen.dart';
import 'plots_screen.dart';

class StatisticsPage extends StatefulWidget {
  final int initialTabIndex;
  const StatisticsPage({super.key, this.initialTabIndex = 0});

  @override
  State<StatisticsPage> createState() => StatisticsPageState();
}

class StatisticsPageState extends State<StatisticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = SupabaseService();
  bool _isLoading = true;
  String? _error;
  List<PlantingPlan> _plans = [];
  List<Crop> _crops = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3, 
      vsync: this, 
      initialIndex: widget.initialTabIndex
    );
    _loadData();
  }

  void resetToPlans() {
    if (mounted && _tabController.index != 0) {
      _tabController.animateTo(0);
    }
  }

  @override
  void didUpdateWidget(StatisticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = _service.currentUser;
      if (user == null) throw Exception("User not logged in");
      
      final plans = await _service.getUserPlantingPlans(user.id);
      final crops = await _service.getCrops();
      
      if (mounted) {
        setState(() {
          _plans = plans;
          _crops = crops;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleStatusChange(PlantingPlan plan, String newStatus) async {
    final l10n = AppLocalizations.of(context)!;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.translate('confirm'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text(
          newStatus == 'cancelled' ? l10n.translate('confirm_cancel') : l10n.translate('confirm_harvest'),
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.translate('cancel'), style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.translate('confirm'), style: GoogleFonts.cairo(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _service.updatePlanStatus(plan.id!, newStatus);
      if (mounted) {
        await _loadData();
        homeScreenKey.currentState?.refreshApp();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDeletePlan(String planId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.translate('confirm_delete'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text(l10n.translate('confirm_delete_pln_desc'), style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.translate('cancel'), style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.translate('delete'), style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _service.deletePlantingPlan(planId);
      if (mounted) {
        await _loadData();
        homeScreenKey.currentState?.refreshApp();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active': return const Color(0xFF00C897);
      case 'harvested': return Colors.blue;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const darkGreen = AppTheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 10),
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: darkGreen,
              unselectedLabelColor: Colors.grey,
              indicatorColor: darkGreen,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
              unselectedLabelStyle: GoogleFonts.cairo(fontSize: 14),
              tabs: [
                Tab(text: l10n.translate('my_plans')),
                Tab(text: l10n.translate('financial_insights')),
                Tab(text: l10n.translate('plots')),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyPlansTab(l10n, darkGreen),
                const FinancialScreen(),
                const PlotsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPlansTab(AppLocalizations l10n, Color darkGreen) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return Center(child: Text('Error: $_error', style: GoogleFonts.cairo(color: Colors.red)));
    
    final lang = Localizations.localeOf(context).languageCode;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: darkGreen,
      child: Column(
        children: [
          GestureDetector(
            onTap: _loadData,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              color: AppTheme.primary.withOpacity(0.05),
              child: Row(
                children: [
                  const Icon(Icons.refresh, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.translate('refresh_hint'),
                      style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _plans.isEmpty 
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.6,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.grass_outlined, size: 80, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Text(l10n.translate('no_plans'), style: GoogleFonts.cairo(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPlanScreen()));
                            if (result == true) {
                              _loadData();
                              homeScreenKey.currentState?.refreshApp();
                            }
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: Text(l10n.translate('add_first_plan'), style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _plans.length,
                  itemBuilder: (context, index) {
                    final plan = _plans[index];
                    final crop = _crops.firstWhere(
                      (c) => c.id == plan.cropId,
                      orElse: () => Crop(id: 0, nameEn: 'Unknown', nameAr: 'غير معروف', emoji: '🌿', avgYield: 0, categoryId: 0),
                    );

                    final isHarvestable = plan.status == 'active' &&
                        DateTime.now().isAfter(plan.harvestDate.subtract(const Duration(days: 14)));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 60, height: 60,
                                  decoration: BoxDecoration(color: _getStatusColor(plan.status).withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                                  alignment: Alignment.center,
                                  child: Text(crop.emoji, style: const TextStyle(fontSize: 32)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(crop.getName(lang), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 20, color: darkGreen)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                        decoration: BoxDecoration(color: _getStatusColor(plan.status).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Text(l10n.translate(plan.status), style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: _getStatusColor(plan.status))),
                                      ),
                                    ],
                                  ),
                                ),
                                if (plan.status == 'cancelled')
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _handleDeletePlan(plan.id!),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            color: const Color(0xFFF8F9FA),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildInfoColumn(l10n.translate('area_donums'), '${plan.areaDonums} ${l10n.translate('dunums')}'),
                                    _buildInfoColumn(l10n.translate('expected_supply'), '${plan.estimatedYieldTons?.toStringAsFixed(1) ?? "0"} ${l10n.translate('tons')}'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildInfoColumn(l10n.translate('planting_date'), DateFormat('yyyy-MM-dd').format(plan.plantingDate)),
                                    _buildInfoColumn(l10n.translate('harvest_date'), DateFormat('yyyy-MM-dd').format(plan.harvestDate)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (plan.status == 'active' || plan.status == 'draft')
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _handleStatusChange(plan, 'cancelled'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                      ),
                                      child: Text(l10n.translate('cancel_plan'), style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (plan.status == 'active')
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          if (isHarvestable) {
                                            _handleStatusChange(plan, 'harvested');
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(l10n.translate('harvest_not_ready'))),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isHarvestable ? darkGreen : Colors.grey[300],
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                        ),
                                        child: Text(l10n.translate('mark_harvested'), style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: isHarvestable ? Colors.white : Colors.grey[600])),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1A233A))),
      ],
    );
  }

  Widget _buildPlaceholder(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(text, style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}
