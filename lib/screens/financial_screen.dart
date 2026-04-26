import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/crop.dart';
import '../models/planting_plan.dart';
import '../models/crop_financial.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import 'add_financial_screen.dart';

class FinancialScreen extends StatefulWidget {
  const FinancialScreen({super.key});

  @override
  State<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen> {
  final _service = SupabaseService();
  bool _isLoading = true;
  List<CropFinancial> _financials = [];
  List<PlantingPlan> _activePlans = [];
  List<Crop> _allCrops = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = _service.currentUser;
      if (user == null) return;

      // 1. Fetch data from Supabase
      final financials = await _service.getCropFinancials(user.id);
      final plans = await _service.getUserPlantingPlans(user.id);
      final crops = await _service.getCrops();

      if (mounted) {
        setState(() {
          _financials = financials;
          // Filter only active plans for yield calculation
          _activePlans = plans.where((p) => p.status == 'active').toList();
          _allCrops = crops;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const darkGreen = Color(0xFF005E4D);
    const primaryGreen = Color(0xFF00C897);

    if (_isLoading) return const Center(child: CircularProgressIndicator(color: primaryGreen));

    // --- Totals Calculation ---
    double totalRevenue = 0;
    double totalExpenses = 0;

    for (var fin in _financials) {
      // Sum estimated yield for this specific crop
      double cropYield = _activePlans
          .where((p) => p.cropId == fin.cropId)
          .fold(0.0, (sum, p) => sum + (p.estimatedYieldTons ?? 0.0));
      
      totalRevenue += cropYield * fin.sellingPricePerTon;
      totalExpenses += fin.totalExpenses;
    }
    double totalProfit = totalRevenue - totalExpenses;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryHeader(l10n, totalRevenue, totalExpenses, totalProfit),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.translate('crops_list'),
                    style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: darkGreen),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddFinancialScreen()),
                      );
                      if (result == true) _loadData();
                    },
                    icon: const Icon(Icons.add, color: primaryGreen),
                    label: Text(l10n.translate('add_financial_data'), style: GoogleFonts.cairo(color: primaryGreen, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_financials.isEmpty)
                _buildEmptyState(l10n)
              else
                ..._financials.map((fin) => _buildCropFinancialCard(l10n, fin)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(AppLocalizations l10n, double revenue, double expenses, double profit) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A233A),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          _buildSummaryRow(l10n.translate('total_revenue'), revenue, Colors.white),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white24)),
          _buildSummaryRow(l10n.translate('total_expenses'), expenses, Colors.redAccent),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white24)),
          _buildSummaryRow(
            l10n.translate('total_profit_summary'), 
            profit, 
            profit >= 0 ? const Color(0xFF00C897) : Colors.red,
            isBold: true
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, Color color, {bool isBold = false}) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16)),
        Text(
          '${value.toStringAsFixed(2)} ${l10n.translate('jod')}',
          style: GoogleFonts.cairo(
            color: color, 
            fontSize: isBold ? 22 : 18, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600
          ),
        ),
      ],
    );
  }

  Widget _buildCropFinancialCard(AppLocalizations l10n, CropFinancial fin) {
    final lang = Localizations.localeOf(context).languageCode;
    final crop = _allCrops.firstWhere(
      (c) => c.id == fin.cropId,
      orElse: () => Crop(id: 0, nameEn: 'Unknown', nameAr: 'غير معروف', emoji: '🌱', avgYield: 0, categoryId: 0),
    );

    // --- Calculations ---
    double cropYield = _activePlans
        .where((p) => p.cropId == fin.cropId)
        .fold(0.0, (sum, p) => sum + (p.estimatedYieldTons ?? 0.0));
    
    double revenue = cropYield * fin.sellingPricePerTon;
    double profit = revenue - fin.totalExpenses;
    double margin = revenue > 0 ? (profit / revenue) * 100 : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddFinancialScreen(existingFinancial: fin)),
          );
          if (result == true) _loadData();
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Text(crop.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Text(crop.getName(lang), style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (profit >= 0 ? Colors.green : Colors.red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${margin.toStringAsFixed(1)}%',
                      style: GoogleFonts.cairo(
                        color: profit >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStat(l10n.translate('revenue'), revenue, Colors.black87),
                  _buildStat(l10n.translate('expenses'), fin.totalExpenses, Colors.redAccent),
                  _buildStat(l10n.translate('profit'), profit, profit >= 0 ? Colors.green : Colors.red),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, double value, Color valueColor) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12)),
        Text(
          '${value.toStringAsFixed(0)} ${l10n.translate('jod')}',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: valueColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(l10n.translate('no_financial_data'), style: GoogleFonts.cairo(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
