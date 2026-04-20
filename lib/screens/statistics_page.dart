import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/planting_plan.dart';
import '../models/crop.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import 'add_plan_screen.dart';
import 'home_screen.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = SupabaseService();
  bool _isLoading = true;
  String? _error;
  List<PlantingPlan> _plans = [];
  List<Crop> _crops = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
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
            child: Text(l10n.translate('confirm'), style: GoogleFonts.cairo(color: const Color(0xFF00C897), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _service.updatePlanStatusWithSupply(plan, newStatus);
      
      if (mounted) {
        // Refresh the whole app to update dashboard stats
        homeScreenKey.currentState?.refreshApp();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return const Color(0xFF00C897);
      case 'harvested':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const primaryGreen = Color(0xFF00C897);
    const darkGreen = Color(0xFF005E4D);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 10),
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: primaryGreen,
              unselectedLabelColor: Colors.grey,
              indicatorColor: primaryGreen,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
              unselectedLabelStyle: GoogleFonts.cairo(fontSize: 14),
              tabs: [
                Tab(text: l10n.translate('my_plans')),
                Tab(text: l10n.translate('supply_analysis')),
                Tab(text: l10n.translate('demand_insights')),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyPlansTab(l10n, darkGreen, primaryGreen),
                _buildPlaceholder(l10n.translate('coming_soon')),
                _buildPlaceholder(l10n.translate('coming_soon')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPlansTab(AppLocalizations l10n, Color darkGreen, Color primaryGreen) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00C897)));
    if (_error != null) return Center(child: Text('Error: $_error', style: GoogleFonts.cairo(color: Colors.red)));
    
    if (_plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.grass_outlined, size: 80, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(l10n.translate('no_plans'), style: GoogleFonts.cairo(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPlanScreen()));
                if (result == true) {
                   // AddPlanScreen already calls homeScreenKey.currentState?.refreshApp()
                }
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(l10n.translate('add_first_plan'), style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 4,
              ),
            ),
          ],
        ),
      );
    }

    final lang = Localizations.localeOf(context).languageCode;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _getStatusColor(plan.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        alignment: Alignment.center,
                        child: Text(crop.emoji, style: const TextStyle(fontSize: 32)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              crop.getName(lang),
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 20, color: darkGreen),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(plan.status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                l10n.translate(plan.status),
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(plan.status),
                                ),
                              ),
                            ),
                          ],
                        ),
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
                                    SnackBar(
                                      content: Text(l10n.translate('harvest_not_ready')),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isHarvestable ? primaryGreen : Colors.grey[300],
                                elevation: isHarvestable ? 2 : 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: Text(
                                l10n.translate('mark_harvested'), 
                                style: GoogleFonts.cairo(
                                  fontSize: 14, 
                                  fontWeight: FontWeight.bold,
                                  color: isHarvestable ? Colors.white : Colors.grey[600]
                                )
                              ),
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
          Text(
            text,
            style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
