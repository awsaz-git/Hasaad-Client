import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlotsScreen extends StatefulWidget {
  const PlotsScreen({super.key});

  @override
  State<PlotsScreen> createState() => _PlotsScreenState();
}

class _PlotsScreenState extends State<PlotsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _hasError = false;

  // 1. Demand — top 8 and bottom 3 crops by avg demand score
  List<_CropValue> _highDemand = [];
  List<_CropValue> _lowDemand = [];

  // 2. Top 5 Selling
  List<_CropValue> _topSelling = [];

  // 3. Fertilizer — top 8
  List<_CropValue> _fertilizer = [];

  // 4. Water — top 8
  List<_CropValue> _water = [];

  // 5. Sales Over Time (market-wide)
  List<_TimeValue> _salesTrend = [];

  // 6. Profit vs Expenses (market-wide)
  List<_FinanceMonth> _financeMonths = [];

  // 7. Yield per Area — top 8
  List<_CropValue> _yieldPerArea = [];

  final _compactFormat = NumberFormat.compact();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _supabase.from('analytics_dataset').select() as List<dynamic>;

      if (data.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // ── 1. Demand ────────────────────────────────────────────────────────
      final Map<String, List<double>> demandMap = {};
      for (var row in data) {
        final name = row['crop_name'] as String?;
        final score = (row['demand_score'] as num?)?.toDouble();
        if (name != null && score != null) {
          demandMap.putIfAbsent(name, () => []).add(score);
        }
      }
      final demandAvg = demandMap.entries
          .map((e) => _CropValue(e.key, e.value.reduce((a, b) => a + b) / e.value.length))
          .toList()..sort((a, b) => b.value.compareTo(a.value));
      _highDemand = demandAvg.take(8).toList();
      _lowDemand = demandAvg.reversed.take(3).toList().reversed.toList();

      // ── 2. Top 5 Selling ─────────────────────────────────────────────────
      final Map<String, double> salesMap = {};
      for (var row in data) {
        final name = row['crop_name'] as String?;
        final sales = (row['total_sales'] as num?)?.toDouble() ?? 0.0;
        if (name != null) salesMap[name] = (salesMap[name] ?? 0) + sales;
      }
      _topSelling = (salesMap.entries
          .map((e) => _CropValue(e.key, e.value))
          .toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(5).toList();

      // ── 3. Fertilizer ────────────────────────────────────────────────────
      final Map<String, List<double>> fertMap = {};
      for (var row in data) {
        final name = row['crop_name'] as String?;
        final val = (row['fertilizer_used'] as num?)?.toDouble();
        if (name != null && val != null) fertMap.putIfAbsent(name, () => []).add(val);
      }
      _fertilizer = (fertMap.entries
          .map((e) => _CropValue(e.key, e.value.reduce((a, b) => a + b) / e.value.length))
          .toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(8).toList();

      // ── 4. Water ─────────────────────────────────────────────────────────
      final Map<String, List<double>> waterMap = {};
      for (var row in data) {
        final name = row['crop_name'] as String?;
        final val = (row['water_used'] as num?)?.toDouble();
        if (name != null && val != null) waterMap.putIfAbsent(name, () => []).add(val);
      }
      _water = (waterMap.entries
          .map((e) => _CropValue(e.key, e.value.reduce((a, b) => a + b) / e.value.length))
          .toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(8).toList();

      // ── 5. Sales Over Time ───────────────────────────────────────────────
      final Map<String, double> salesTime = {};
      for (var row in data) {
        final date = row['sale_date'] as String?;
        if (date != null && date.length >= 7) {
          final month = date.substring(0, 7);
          salesTime[month] = (salesTime[month] ?? 0) + ((row['total_sales'] as num?)?.toDouble() ?? 0);
        }
      }
      final sortedTime = salesTime.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      // Keep last 12 months max
      final recentTime = sortedTime.length > 12 ? sortedTime.sublist(sortedTime.length - 12) : sortedTime;
      _salesTrend = recentTime.map((e) => _TimeValue(e.key, e.value)).toList();

      // ── 6. Profit vs Expenses ────────────────────────────────────────────
      final Map<String, _FinanceMonth> finMap = {};
      for (var row in data) {
        final date = row['sale_date'] as String?;
        if (date != null && date.length >= 7) {
          final month = date.substring(0, 7);
          finMap.putIfAbsent(month, () => _FinanceMonth(month));
          finMap[month]!.profit += (row['profit'] as num?)?.toDouble() ?? 0;
          finMap[month]!.expenses += (row['total_expenses'] as num?)?.toDouble() ?? 0;
        }
      }
      final sortedFin = finMap.values.toList()..sort((a, b) => a.month.compareTo(b.month));
      _financeMonths = sortedFin.length > 6 ? sortedFin.sublist(sortedFin.length - 6) : sortedFin;

      // ── 7. Yield per Area ────────────────────────────────────────────────
      final Map<String, List<double>> yieldMap = {};
      for (var row in data) {
        final name = row['crop_name'] as String?;
        final y = (row['actual_yield'] as num?)?.toDouble() ?? 0;
        final a = (row['area_size'] as num?)?.toDouble() ?? 0;
        if (name != null && a > 0) yieldMap.putIfAbsent(name, () => []).add(y / a);
      }
      _yieldPerArea = (yieldMap.entries
          .map((e) => _CropValue(e.key, e.value.reduce((a, b) => a + b) / e.value.length))
          .toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(8).toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('PlotsScreen Error: $e');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_hasError) return Center(child: Text('Failed to load data. Pull to refresh.', style: GoogleFonts.cairo()));

    return RefreshIndicator(
      onRefresh: () async {
        setState(() { _isLoading = true; _hasError = false; });
        await _loadData();
      },
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            _buildExplanationCard(l10n),
            const SizedBox(height: 24),

            // 1. Demand
            _buildChartCard(
              title: 'أعلى المحاصيل طلباً في السوق',
              titleEn: 'Highest Market Demand Crops',
              subtitle: 'متوسط درجة الطلب لكل محصول',
              subtitleEn: 'Average demand score per crop',
              unit: 'Score',
              color: AppTheme.primary,
              child: _buildCropBarChart(_highDemand, AppTheme.primary, 'Score'),
              l10n: l10n,
            ),

            // 2. Top 5 Selling
            _buildChartCard(
              title: 'أعلى 5 محاصيل مبيعاً',
              titleEn: 'Top 5 Selling Crops',
              subtitle: 'إجمالي المبيعات في السوق',
              subtitleEn: 'Total market sales per crop',
              unit: 'JOD',
              color: const Color(0xFF00C897),
              child: _buildCropBarChart(_topSelling, const Color(0xFF00C897), 'JOD'),
              l10n: l10n,
            ),

            // 3. Fertilizer
            _buildChartCard(
              title: 'استخدام الأسمدة بالمحصول',
              titleEn: 'Fertilizer Usage by Crop',
              subtitle: 'متوسط كمية الأسمدة المستخدمة (كغ/هكتار)',
              subtitleEn: 'Average fertilizer used (kg/ha)',
              unit: 'kg/ha',
              color: Colors.orange,
              child: _buildCropBarChart(_fertilizer, Colors.orange, 'kg/ha'),
              l10n: l10n,
            ),

            // 4. Water
            _buildChartCard(
              title: 'استخدام المياه بالمحصول',
              titleEn: 'Water Usage by Crop',
              subtitle: 'متوسط كمية المياه المستخدمة (م³/هكتار)',
              subtitleEn: 'Average water used (m³/ha)',
              unit: 'm³/ha',
              color: Colors.blue,
              child: _buildCropBarChart(_water, Colors.blue, 'm³/ha'),
              l10n: l10n,
            ),

            // 5. Sales Over Time
            _buildChartCard(
              title: 'مبيعات السوق عبر الزمن',
              titleEn: 'Market Sales Over Time',
              subtitle: 'إجمالي مبيعات جميع المحاصيل شهرياً (بيانات السوق)',
              subtitleEn: 'Total monthly sales across all crops (market data)',
              unit: 'JOD',
              color: AppTheme.primary,
              child: _buildLineChart(),
              l10n: l10n,
            ),

            // 6. Profit vs Expenses
            _buildChartCard(
              title: 'الأرباح مقابل المصاريف',
              titleEn: 'Profit vs Expenses',
              subtitle: 'مقارنة شهرية للأرباح والمصاريف في السوق',
              subtitleEn: 'Monthly market-wide profit and expense comparison',
              unit: 'JOD',
              color: const Color(0xFF00C897),
              child: _buildProfitVsExpensesChart(),
              l10n: l10n,
            ),

            // 7. Yield per Area
            _buildChartCard(
              title: 'الإنتاجية لكل دونم',
              titleEn: 'Yield per Area',
              subtitle: 'متوسط الغلة لكل وحدة مساحة (طن/دونم)',
              subtitleEn: 'Average yield per unit area (ton/donum)',
              unit: 'ton/donum',
              color: Colors.deepPurpleAccent,
              child: _buildCropBarChart(_yieldPerArea, Colors.deepPurpleAccent, 'ton/donum'),
              l10n: l10n,
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String titleEn,
    required String subtitle,
    required String subtitleEn,
    required String unit,
    required Color color,
    required Widget child,
    required AppLocalizations l10n,
  }) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Expanded(child: Text(
              isAr ? title : titleEn,
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1A233A)),
            )),
          ]),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              isAr ? subtitle : subtitleEn,
              style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildCropBarChart(List<_CropValue> items, Color color, String unit) {
    if (items.isEmpty) {
      return SizedBox(height: 160, child: Center(child: Text('No data', style: GoogleFonts.cairo(color: Colors.grey))));
    }

    final maxY = items.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal bar chart — much more readable than vertical for many crops
        ...items.asMap().entries.map((entry) {
          final item = entry.value;
          final pct = maxY > 0 ? item.value / maxY : 0.0;
          final shortName = item.crop.length > 14 ? '${item.crop.substring(0, 12)}..' : item.crop;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(shortName, style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF1A233A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Container(height: 22, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6))),
                      FractionallySizedBox(
                        widthFactor: pct.toDouble(),
                        child: Container(height: 22, decoration: BoxDecoration(color: color.withOpacity(0.85), borderRadius: BorderRadius.circular(6))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  child: Text(
                    _compactFormat.format(item.value),
                    style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Text(unit, style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey[400])),
      ],
    );
  }

  Widget _buildLineChart() {
    if (_salesTrend.isEmpty) {
      return SizedBox(height: 180, child: Center(child: Text('No data', style: GoogleFonts.cairo(color: Colors.grey))));
    }

    final spots = _salesTrend.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    final maxY = _salesTrend.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: LineChart(LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppTheme.primary,
                barWidth: 2.5,
                dotData: FlDotData(show: spots.length <= 12),
                belowBarData: BarAreaData(show: true, color: AppTheme.primary.withOpacity(0.08)),
              ),
            ],
            minY: 0,
            maxY: maxY * 1.2,
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (_salesTrend.length / 4).ceilToDouble(),
                getTitlesWidget: (val, _) {
                  final i = val.toInt();
                  if (i < 0 || i >= _salesTrend.length) return const SizedBox.shrink();
                  final label = _salesTrend[i].month.length >= 7 ? _salesTrend[i].month.substring(2, 7) : _salesTrend[i].month;
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(label, style: GoogleFonts.cairo(fontSize: 9, color: Colors.grey[600])));
                },
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (val, _) => Text(_compactFormat.format(val), style: GoogleFonts.cairo(fontSize: 9, color: Colors.grey[500])),
              )),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1)),
            borderData: FlBorderData(show: false),
          )),
        ),
        const SizedBox(height: 4),
        Text('JOD', style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey[400])),
      ],
    );
  }

  Widget _buildProfitVsExpensesChart() {
    if (_financeMonths.isEmpty) {
      return SizedBox(height: 180, child: Center(child: Text('No data', style: GoogleFonts.cairo(color: Colors.grey))));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._financeMonths.map((fm) {
          final maxVal = _financeMonths.map((e) => e.profit > e.expenses ? e.profit : e.expenses).reduce((a, b) => a > b ? a : b);
          final profitPct = maxVal > 0 ? (fm.profit / maxVal).clamp(0.0, 1.0) : 0.0;
          final expPct = maxVal > 0 ? (fm.expenses / maxVal).clamp(0.0, 1.0) : 0.0;
          final label = fm.month.length >= 7 ? fm.month.substring(2, 7) : fm.month;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey[500])),
                const SizedBox(height: 3),
                Row(children: [
                  SizedBox(width: 52, child: Text('Profit', style: GoogleFonts.cairo(fontSize: 10, color: const Color(0xFF00C897)))),
                  Expanded(child: Stack(children: [
                    Container(height: 14, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(widthFactor: profitPct, child: Container(height: 14, decoration: BoxDecoration(color: const Color(0xFF00C897).withOpacity(0.85), borderRadius: BorderRadius.circular(4)))),
                  ])),
                  SizedBox(width: 52, child: Text(' ${_compactFormat.format(fm.profit)}', style: GoogleFonts.cairo(fontSize: 10, color: const Color(0xFF00C897)), textAlign: TextAlign.right)),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  SizedBox(width: 52, child: Text('Expenses', style: GoogleFonts.cairo(fontSize: 10, color: Colors.redAccent))),
                  Expanded(child: Stack(children: [
                    Container(height: 14, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(widthFactor: expPct, child: Container(height: 14, decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.85), borderRadius: BorderRadius.circular(4)))),
                  ])),
                  SizedBox(width: 52, child: Text(' ${_compactFormat.format(fm.expenses)}', style: GoogleFonts.cairo(fontSize: 10, color: Colors.redAccent), textAlign: TextAlign.right)),
                ]),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Text('JOD', style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey[400])),
      ],
    );
  }

  Widget _buildExplanationCard(AppLocalizations l10n) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_graph, color: AppTheme.primary),
            const SizedBox(width: 12),
            Text(
              isAr ? 'تحليلات السوق' : 'Market Analytics',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.primary),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            isAr
                ? 'تعرض هذه الرسوم البيانية بيانات السوق الزراعي الأردني من قاعدة بيانات التحليلات. تساعدك على فهم اتجاهات السوق واتخاذ قرارات زراعية أذكى.'
                : 'These charts display Jordanian agricultural market data from our analytics dataset. Use them to understand market trends and make smarter farming decisions.',
            style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey[600], height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _CropValue {
  final String crop;
  final double value;
  _CropValue(this.crop, this.value);
}

class _TimeValue {
  final String month;
  final double value;
  _TimeValue(this.month, this.value);
}

class _FinanceMonth {
  final String month;
  double profit;
  double expenses;
  _FinanceMonth(this.month) : profit = 0, expenses = 0;
}
