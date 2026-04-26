import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/planting_plan.dart';
import '../models/crop.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import 'home_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _service = SupabaseService();
  bool _isLoading = true;
  List<PlantingPlan> _plans = [];
  List<Crop> _crops = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Switch to My Plans tab (index 3) whenever this screen is entered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      homeScreenKey.currentState?.setSelectedIndex(3);
    });
  }

  Future<void> _loadData() async {
    try {
      final user = _service.currentUser;
      if (user == null) return;
      
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Logic to handle status changes (Harvest/Cancel)
  Future<void> _handleStatusChange(PlantingPlan plan, String newStatus) async {
    setState(() => _isLoading = true);
    try {
      // Rule: This method handles database update AND supply subtraction if needed
      await _service.updatePlanStatusWithSupply(plan, newStatus);
      await _loadData(); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    const darkGreen = Color(0xFF005E4D);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('my_plans'), 
            style: GoogleFonts.cairo(color: darkGreen, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? Center(child: Text(l10n.translate('no_plans'), style: GoogleFonts.cairo()))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _plans.length,
                    itemBuilder: (context, index) {
                      final plan = _plans[index];
                      final crop = _crops.firstWhere(
                        (c) => c.id == plan.cropId, 
                        orElse: () => Crop(id: 0, nameEn: '', nameAr: '', emoji: '🌿', avgYield: 0, categoryId: 0)
                      );

                      final isHarvestable = plan.status == 'active' && 
                          DateTime.now().isAfter(plan.harvestDate.subtract(const Duration(days: 7)));

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ExpansionTile(
                          leading: Text(crop.emoji, style: const TextStyle(fontSize: 24)),
                          title: Text(crop.getName(lang), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${plan.areaDonums} ${l10n.translate('dunums')} • ${l10n.translate(plan.status)}', 
                            style: GoogleFonts.cairo(
                              fontSize: 12, 
                              color: plan.status == 'active' ? Colors.green : Colors.grey
                            )
                          ),
                          children: [
                            if (plan.status == 'active')
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Cancel Button: Always allowed if active
                                    TextButton.icon(
                                      onPressed: () => _handleStatusChange(plan, 'cancelled'),
                                      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                      label: Text(l10n.translate('cancelled'), style: GoogleFonts.cairo(color: Colors.red)),
                                    ),
                                    const SizedBox(width: 8),
                                    // Harvest Button: Allowed if within 7 days of harvest date
                                    ElevatedButton.icon(
                                      onPressed: isHarvestable ? () => _handleStatusChange(plan, 'harvested') : null,
                                      icon: const Icon(Icons.grass, color: Colors.white),
                                      label: Text(l10n.translate('harvested'), style: GoogleFonts.cairo(color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        disabledBackgroundColor: Colors.grey.shade300,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow(l10n.translate('planting_date'), plan.plantingDate.toString().split(' ')[0]),
                                  _buildDetailRow(l10n.translate('harvest_date'), plan.harvestDate.toString().split(' ')[0]),
                                  _buildDetailRow(l10n.translate('expected_supply'), '${plan.estimatedYieldTons?.toStringAsFixed(1) ?? "0"} ${l10n.translate('tons')}'),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13)),
          Text(value, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
