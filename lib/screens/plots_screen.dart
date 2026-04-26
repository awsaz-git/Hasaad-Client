import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';

class PlotsScreen extends StatefulWidget {
  const PlotsScreen({super.key});

  @override
  State<PlotsScreen> createState() => _PlotsScreenState();
}

class _PlotsScreenState extends State<PlotsScreen> {
  final _service = SupabaseService();
  bool _isLoading = true;
  bool _hasError = false;
  bool _isInitialized = false;
  
  // Data for charts
  List<BarChartGroupData> _demandGroups = [];
  List<String> _demandCropNames = [];
  
  List<PieChartSectionData> _topSellingSections = [];
  List<Map<String, dynamic>> _topSellingLegend = [];
  
  List<BarChartGroupData> _resourceGroups = [];
  List<FlSpot> _salesTrendSpots = [];
  List<BarChartGroupData> _profitGroups = [];

  // Formatting helpers
  final _compactFormat = NumberFormat.compact();
  final _decimalFormat = NumberFormat('#,##0.00');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadData();
      _isInitialized = true;
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      debugPrint('PlotsScreen: Fetching data...');
      
      // Get data from service first
      final demandMap = await _service.getCropDemandMap();
      final crops = await _service.getCrops();

      if (!mounted) return;
      
      final l10n = AppLocalizations.of(context);
      final isAr = l10n?.locale.languageCode == 'ar';
      
      // 1. Demand Chart Data
      var sortedDemand = demandMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      var top5Demand = sortedDemand.take(5).toList();
      
      _demandCropNames = top5Demand.map((e) {
        final crop = crops.firstWhere(
          (c) => c.id == e.key, 
          orElse: () => crops.isNotEmpty ? crops.first : throw Exception("No crops found")
        );
        return isAr ? crop.nameAr : crop.nameEn;
      }).toList();

      _demandGroups = top5Demand.asMap().entries.map((entry) {
        return BarChartGroupData(
          x: entry.key,
          barRods: [
            BarChartRodData(
              toY: entry.value.value, 
              color: AppTheme.primary, 
              width: 18, 
              borderRadius: BorderRadius.circular(4)
            )
          ],
        );
      }).toList();

      // 2. Top Selling (Pie Chart) - Localized labels
      _topSellingLegend = [
        {'label': l10n?.translate('tomato') ?? 'Tomato', 'color': AppTheme.primary, 'value': 40.0},
        {'label': l10n?.translate('wheat') ?? 'Wheat', 'color': const Color(0xFF00C897), 'value': 30.0},
        {'label': l10n?.translate('olive') ?? 'Olive', 'color': Colors.orange, 'value': 15.0},
        {'label': l10n?.translate('cucumber') ?? 'Cucumber', 'color': Colors.blue, 'value': 10.0},
        {'label': l10n?.translate('other') ?? 'Other', 'color': Colors.grey, 'value': 5.0},
      ];
      _topSellingSections = _topSellingLegend.map((item) {
        return PieChartSectionData(
          value: item['value'],
          title: '${item['value']}%',
          color: item['color'],
          radius: 50,
          titleStyle: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
        );
      }).toList();

      // 3. Resource Usage
      _resourceGroups = [
        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 520.5, color: Colors.blue.shade400, width: 22, borderRadius: BorderRadius.circular(4))]),
        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 340.2, color: Colors.orange.shade400, width: 22, borderRadius: BorderRadius.circular(4))]),
      ];

      // 4. Sales Trend
      _salesTrendSpots = [
        const FlSpot(0, 1200), const FlSpot(1, 1500), const FlSpot(2, 1350), 
        const FlSpot(3, 2100), const FlSpot(4, 2550), const FlSpot(5, 2300),
      ];

      // 5. Profit vs Expenses
      _profitGroups = [
        BarChartGroupData(x: 0, barRods: [
          BarChartRodData(toY: 15400.50, color: const Color(0xFF00C897), width: 16), // Profit (Green)
          BarChartRodData(toY: 9200.75, color: Colors.red.shade400, width: 16),      // Expenses (Red)
        ]),
      ];

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('PlotsScreen Error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const primary = AppTheme.primary;

    if (_isLoading) return const Center(child: CircularProgressIndicator(color: primary));

    if (_hasError) return _buildNoData(l10n);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          _buildExplanationCard(l10n),
          const SizedBox(height: 24),
          
          // Chart 1: Market Demand
          _buildChartCard(
            title: l10n.translate('highest_lowest_demand'),
            subtitle: l10n.translate('demand_subtitle'),
            child: _demandGroups.isEmpty ? _buildNoData(l10n) : AspectRatio(
              aspectRatio: 1.6,
              child: BarChart(BarChartData(
                barGroups: _demandGroups,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text(l10n.translate('crop'), style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        int index = val.toInt();
                        if (index >= 0 && index < _demandCropNames.length) {
                          String name = _demandCropNames[index];
                          // Truncate if too long
                          if (name.length > 8) name = "${name.substring(0, 6)}..";
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(name, style: GoogleFonts.cairo(fontSize: 9)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(l10n.translate('demand'), style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold)),
                    sideTitles: SideTitles(
                      showTitles: true, 
                      reservedSize: 40, 
                      getTitlesWidget: (val, _) => Text(_compactFormat.format(val), style: GoogleFonts.cairo(fontSize: 10))
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.blueGrey.withOpacity(0.9),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                      _decimalFormat.format(rod.toY),
                      GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              )),
            ),
          ),

          // Chart 2: Top Selling Crops
          _buildChartCard(
            title: l10n.translate('top_5_selling'),
            subtitle: l10n.translate('selling_subtitle'),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1.6,
                  child: PieChart(PieChartData(sections: _topSellingSections, centerSpaceRadius: 40)),
                ),
                const SizedBox(height: 24),
                _buildLegend(_topSellingLegend.map((e) => {'label': e['label'], 'color': e['color']}).toList()),
              ],
            ),
          ),

          // Chart 3: Resource Usage
          _buildChartCard(
            title: l10n.translate('resource_usage'),
            subtitle: l10n.translate('resource_subtitle'),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1.6,
                  child: BarChart(BarChartData(
                    barGroups: _resourceGroups,
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, 
                          getTitlesWidget: (val, _) {
                            String label = val == 0 ? l10n.translate('water') : l10n.translate('fertilizer');
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(label, style: GoogleFonts.cairo(fontSize: 10)),
                            );
                          }
                        )
                      ),
                      leftTitles: AxisTitles(
                        axisNameWidget: Text(l10n.translate('tons') + "/m³", style: GoogleFonts.cairo(fontSize: 9, fontWeight: FontWeight.bold)),
                        sideTitles: SideTitles(
                          showTitles: true, 
                          reservedSize: 40, 
                          getTitlesWidget: (val, _) => Text(_compactFormat.format(val), style: GoogleFonts.cairo(fontSize: 10))
                        )
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 200),
                  )),
                ),
                const SizedBox(height: 16),
                _buildLegend([
                  {'label': l10n.translate('water'), 'color': Colors.blue.shade400},
                  {'label': l10n.translate('fertilizer'), 'color': Colors.orange.shade400},
                ]),
              ],
            ),
          ),

          // Chart 4: Sales Trend
          _buildChartCard(
            title: l10n.translate('sales_over_time'),
            subtitle: l10n.translate('sales_subtitle'),
            child: AspectRatio(
              aspectRatio: 1.6,
              child: LineChart(LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: _salesTrendSpots, 
                    isCurved: true, 
                    color: AppTheme.primary, 
                    barWidth: 3, 
                    isStrokeCapRound: true, 
                    dotData: const FlDotData(show: true), 
                    belowBarData: BarAreaData(show: true, color: AppTheme.primary.withOpacity(0.1))
                  )
                ],
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text(l10n.translate('date'), style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold)),
                    sideTitles: const SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(l10n.translate('jod'), style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold)),
                    sideTitles: SideTitles(
                      showTitles: true, 
                      reservedSize: 40, 
                      getTitlesWidget: (val, _) => Text(_compactFormat.format(val), style: GoogleFonts.cairo(fontSize: 10))
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
              )),
            ),
          ),

          // Chart 5: Profit vs Expenses
          _buildChartCard(
            title: l10n.translate('profit_vs_expenses'),
            subtitle: l10n.translate('profit_subtitle'),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1.6,
                  child: BarChart(BarChartData(
                    barGroups: _profitGroups,
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        axisNameWidget: Text(l10n.translate('jod'), style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold)),
                        sideTitles: SideTitles(
                          showTitles: true, 
                          reservedSize: 45, 
                          getTitlesWidget: (val, _) => Text(_compactFormat.format(val), style: GoogleFonts.cairo(fontSize: 10))
                        )
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                  )),
                ),
                const SizedBox(height: 16),
                _buildLegend([
                  {'label': l10n.translate('profit'), 'color': const Color(0xFF00C897)},
                  {'label': l10n.translate('expenses_label'), 'color': Colors.red.shade400},
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_outlined, color: AppTheme.primary, size: 22),
              const SizedBox(width: 12),
              Text(
                l10n.translate('plots_explanation_title'),
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.translate('plots_explanation_desc'),
            style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[700], height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(List<Map<String, dynamic>> items) {
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: items.map((item) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: item['color'] as Color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(item['label'] as String, style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey[800])),
        ],
      )).toList(),
    );
  }

  Widget _buildChartCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF1A233A))),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[500], height: 1.3)),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }

  Widget _buildNoData(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(l10n.translate('no_data_chart'), style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }
}
