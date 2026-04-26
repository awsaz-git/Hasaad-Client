import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../models/crop.dart';
import '../models/category.dart';
import '../models/profile.dart';
import '../models/planting_plan.dart';
import '../models/governorate.dart';
import '../services/supabase_service.dart';
import '../services/weather_service.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';
import '../widgets/crop_card.dart';
import '../widgets/category_filter.dart';
import 'add_plan_screen.dart';
import 'suggest_feature_screen.dart';

class HomeDashboard extends StatefulWidget {
  final VoidCallback? onViewPlans;
  const HomeDashboard({super.key, this.onViewPlans});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _service = SupabaseService();
  final _weatherService = WeatherService();
  bool _isLoading = true;
  Timer? _refreshTimer;
  
  Profile? _profile;
  Governorate? _governorate;
  List<Crop> _crops = [];
  List<CropCategory> _categories = [];
  List<PlantingPlan> _plans = [];
  Map<int, double> _totalSupply = {};
  Map<int, double> _demand = {};
  WeatherData? _weather;
  int? _selectedCategoryId;
  
  String _sortBy = 'none'; 
  int _visibleCropsCount = 6;
  bool _showSuggestionCard = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkSuggestionPopup();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _loadData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSuggestionPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_suggestion_popup') ?? false;

    if (!hasSeen) {
      setState(() {
        _showSuggestionCard = true;
      });
    }
  }

  void _dismissSuggestionCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_suggestion_popup', true);
    setState(() {
      _showSuggestionCard = false;
    });
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final user = _service.currentUser;
      final profile = await _service.getProfile(user!.id);
      final crops = await _service.getCrops();
      final categories = await _service.getCategories();
      final plans = await _service.getUserPlantingPlans(user.id);
      final totalSupply = await _service.getTotalCropSupplyMap();
      final demand = await _service.getCropDemandMap();
      
      final govs = await _service.getGovernorates();
      final myGov = govs.firstWhere((g) => g.id == profile!.governorateId);

      _weatherService.fetchWeather().then((w) {
        if (mounted) setState(() => _weather = w);
      });

      if (mounted) {
        setState(() {
          _profile = profile;
          _governorate = myGov;
          _crops = crops;
          _categories = categories;
          _plans = plans;
          _totalSupply = totalSupply;
          _demand = demand;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _shareApp() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Share.share(l10n.translate('share_message'));
    } catch (e) {
      debugPrint('Error sharing: $e');
    }
  }

  double get usedArea => _plans.where((p) => p.status == 'active').fold(0, (sum, plan) => sum + plan.areaDonums);
  double get totalArea => _profile?.landSize ?? 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    const primaryColor = AppTheme.primary;
    const addPlanColor = Color(0xFF00C897); 

    if (_isLoading) return const Center(child: CircularProgressIndicator(color: primaryColor));

    List<Crop> filteredCrops = _selectedCategoryId == null 
        ? List.from(_crops) 
        : _crops.where((c) => c.categoryId == _selectedCategoryId).toList();

    if (_sortBy != 'none') {
      filteredCrops.sort((a, b) {
        switch (_sortBy) {
          case 'pct_high':
            double rA = (_demand[a.id] ?? 0) > 0 ? ((_totalSupply[a.id] ?? 0) / (_demand[a.id] ?? 0)) : 0;
            double rB = (_demand[b.id] ?? 0) > 0 ? ((_totalSupply[b.id] ?? 0) / (_demand[b.id] ?? 0)) : 0;
            return rB.compareTo(rA);
          case 'pct_low':
            double rA = (_demand[a.id] ?? 0) > 0 ? ((_totalSupply[a.id] ?? 0) / (_demand[a.id] ?? 0)) : 0;
            double rB = (_demand[b.id] ?? 0) > 0 ? ((_totalSupply[b.id] ?? 0) / (_demand[b.id] ?? 0)) : 0;
            return rA.compareTo(rB);
          case 'supply_high':
            return (_totalSupply[b.id] ?? 0).compareTo(_totalSupply[a.id] ?? 0);
          case 'supply_low':
            return (_totalSupply[a.id] ?? 0).compareTo(_totalSupply[b.id] ?? 0);
          case 'demand_high':
            return (_demand[b.id] ?? 0).compareTo(_demand[a.id] ?? 0);
          case 'demand_low':
            return (_demand[a.id] ?? 0).compareTo(_demand[b.id] ?? 0);
          default:
            return 0;
        }
      });
    }

    final cropsToShow = filteredCrops.take(_visibleCropsCount).toList();

    return RefreshIndicator(
      onRefresh: () => _loadData(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 100), 
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.translate('welcome')},',
                        style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600]),
                      ),
                      Text(
                        _profile?.fullName ?? '',
                        style: GoogleFonts.cairo(
                          fontSize: 26, 
                          fontWeight: FontWeight.bold, 
                          color: primaryColor,
                          height: 1.2
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: primaryColor.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            '${_governorate?.getName(lang) ?? ""}, ${l10n.translate('jordan')}',
                            style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildWeatherCard(),
              ],
            ),
            const SizedBox(height: 28),

            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: _buildSmallStatusCard(
                    l10n.translate('farming_condition'), 
                    l10n.translate('farming_status_good'), 
                    Icons.wb_sunny_outlined, 
                    primaryColor, 
                    l10n.translate('based_on_ai')
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSmallStatusCard(
                    l10n.translate('best_planting_time'), 
                    l10n.translate('next_planting_days'), 
                    Icons.calendar_today_outlined, 
                    Colors.blue, 
                    l10n.translate('ai_optimization'),
                    score: "85%"
                  )),
                ],
              ),
            ),
            const SizedBox(height: 28),

            if (_showSuggestionCard) ...[
              _buildSuggestionCard(l10n, primaryColor, lang),
              const SizedBox(height: 28),
            ],

            _buildLandUtilizationCard(l10n, primaryColor),
            const SizedBox(height: 32),
            _buildActionCard(l10n, addPlanColor),
            const SizedBox(height: 32),
            Row(
              children: [
                Text(
                  l10n.translate('market_categories'),
                  style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            CategoryFilter(
              categories: _categories,
              selectedCategoryId: _selectedCategoryId,
              onCategorySelected: (id) => setState(() {
                _selectedCategoryId = id;
                _visibleCropsCount = 6;
              }),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          l10n.translate('market_status'),
                          style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildLiveIndicator(),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildSortButton(l10n, primaryColor),
              ],
            ),
            if (_sortBy != 'none')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  label: Text(
                    '${l10n.translate('filter')}: ${l10n.translate('sort_' + _sortBy)}',
                    style: GoogleFonts.cairo(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  deleteIcon: const Icon(Icons.close, size: 14, color: primaryColor),
                  onDeleted: () => setState(() => _sortBy = 'none'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide.none,
                ),
              ),
            const SizedBox(height: 16),
            if (cropsToShow.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cropsToShow.length,
                itemBuilder: (context, index) {
                  final crop = cropsToShow[index];
                  return CropCard(
                    crop: crop,
                    supply: _totalSupply[crop.id] ?? 0,
                    demand: _demand[crop.id] ?? 0,
                  );
                },
              ),
            if (filteredCrops.length > _visibleCropsCount)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: TextButton.icon(
                    onPressed: () => setState(() => _visibleCropsCount += 6),
                    icon: const Icon(Icons.add, color: primaryColor),
                    label: Text(
                      l10n.translate('load_more'),
                      style: GoogleFonts.cairo(color: primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 32),
            _buildShareCard(l10n, primaryColor),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStatusCard(String title, String status, IconData icon, Color color, String subtitle, {String? score}) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title, 
                  style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(l10n.translate('coming_soon'), style: GoogleFonts.cairo(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status, 
                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.visible,
                ),
              ),
              if (score != null)
                Text(score, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.6))),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.cairo(fontSize: 9, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(AppLocalizations l10n, Color primaryColor, String lang) {
    bool isAr = lang == 'ar';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withValues(alpha: 0.05), Colors.blue.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(30), 
        border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: isAr ? 12 : null,
            right: isAr ? null : 12,
            top: 12,
            child: GestureDetector(
              onTap: _dismissSuggestionCard,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: isAr ? 30 : 0, 
                          right: isAr ? 0 : 30, 
                        ),
                        child: Text(
                          l10n.translate('request_new_service'),
                          style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.translate('request_service_desc'),
                  style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey[700], height: 1.3),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        _dismissSuggestionCard();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SuggestFeatureScreen()));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          l10n.translate('submit_suggestion'),
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ),
                    const Icon(Icons.lightbulb, color: Colors.orangeAccent, size: 36),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareCard(AppLocalizations l10n, Color primaryGreen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), 
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('share_hasaad'),
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                Text(
                  l10n.translate('help_others_grow'),
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: _shareApp,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF333333), 
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.translate('share'),
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          Icon(
            _weather != null && _weather!.temp > 25 ? Icons.wb_sunny : Icons.wb_cloudy_outlined, 
            color: Colors.orange, 
            size: 28
          ),
          const SizedBox(height: 4),
          Text(
            _weather != null ? '${_weather!.temp.toInt()}°C' : '--°C',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)
          ),
        ],
      ),
    );
  }

  Widget _buildLandUtilizationCard(AppLocalizations l10n, Color primaryColor) {
    double progress = totalArea > 0 ? (usedArea / totalArea) : 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.translate('total_planted_area'), style: GoogleFonts.cairo(color: Colors.white.withValues(alpha: 0.9), fontSize: 16)),
              const Icon(Icons.info_outline, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${usedArea.toStringAsFixed(1)} / ${totalArea.toInt()} ${l10n.translate('dunums')}',
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(progress * 100).toInt()}% ${l10n.translate('land_utilization')}',
            style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(AppLocalizations l10n, Color accentColor) {
    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPlanScreen()));
            if (result == true) _loadData();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('register_plan'),
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.translate('register_plan_hint'),
                        style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
        ),
        if (_plans.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: widget.onViewPlans,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.translate('view_my_plans'),
                      style: GoogleFonts.cairo(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 18, color: accentColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1.0),
        duration: const Duration(seconds: 1),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.withValues(alpha: 1 - value), width: 4),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortButton(AppLocalizations l10n, Color primaryColor) {
    return PopupMenuButton<String>(
      onSelected: (value) => setState(() => _sortBy = value),
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, color: primaryColor, size: 18),
            const SizedBox(width: 8),
            Text(
              l10n.translate('filter'),
              style: GoogleFonts.cairo(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        _buildSortItem('none', l10n.translate('none'), Icons.refresh),
        const PopupMenuDivider(),
        _buildSortItem('pct_high', l10n.translate('sort_pct_high'), Icons.trending_up),
        _buildSortItem('pct_low', l10n.translate('sort_pct_low'), Icons.trending_down),
        const PopupMenuDivider(),
        _buildSortItem('supply_high', l10n.translate('sort_supply_high'), Icons.inventory_2_outlined),
        _buildSortItem('supply_low', l10n.translate('sort_supply_low'), Icons.inventory_2),
        const PopupMenuDivider(),
        _buildSortItem('demand_high', l10n.translate('sort_demand_high'), Icons.shopping_basket_outlined),
        _buildSortItem('demand_low', l10n.translate('sort_demand_low'), Icons.shopping_basket),
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
}
