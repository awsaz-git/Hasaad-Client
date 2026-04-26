import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';
import 'profit_prediction_screen.dart';
import 'yield_prediction_screen.dart';
import 'price_prediction_screen.dart';
import 'demand_prediction_screen.dart';
import 'allocation_prediction_screen.dart';
import 'coming_soon_prediction_screen.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showVoiceAssistant() {
    final l10n = AppLocalizations.of(context)!;
    const primaryGreen = Color(0xFF00C897);
    const darkGreen = AppTheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const CircleAvatar(
              radius: 35,
              backgroundColor: Color(0xFFF0F9F4),
              child: Icon(Icons.mic, color: primaryGreen, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.translate('ai_voice_assistant'),
              style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: darkGreen),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.translate('voice_assistant_desc'),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.translate('coming_soon'),
                style: GoogleFonts.cairo(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
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
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: darkGreen,
              unselectedLabelColor: Colors.grey,
              indicatorColor: darkGreen,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              tabs: [
                Tab(
                  icon: const Icon(Icons.analytics_outlined),
                  text: l10n.translate('predictions'),
                ),
                Tab(
                  icon: const Icon(Icons.smart_toy_outlined),
                  text: l10n.translate('ai_assistant'),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPredictionsTab(l10n, darkGreen),
                _buildAssistantTab(l10n, darkGreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionsTab(AppLocalizations l10n, Color darkGreen) {
    final models = [
      {
        'id': 'profit',
        'title': l10n.translate('profit_prediction'),
        'desc': l10n.translate('profit_prediction_desc'),
        'icon': Icons.monetization_on_outlined,
        'color': const Color(0xFF00C897),
        'screen': const ProfitPredictionScreen(),
      },
      {
        'id': 'yield',
        'title': l10n.translate('yield_prediction'),
        'desc': l10n.translate('yield_prediction_desc'),
        'icon': Icons.grass_outlined,
        'color': const Color(0xFF6C63FF),
        'screen': const YieldPredictionScreen(),
      },
      {
        'id': 'price',
        'title': l10n.translate('price_prediction'),
        'desc': l10n.translate('price_prediction_desc'),
        'icon': Icons.sell_outlined,
        'color': const Color(0xFFFF9F43),
        'screen': const PricePredictionScreen(),
      },
      {
        'id': 'demand',
        'title': l10n.translate('demand_prediction'),
        'desc': l10n.translate('demand_prediction_desc'),
        'icon': Icons.analytics_outlined,
        'color': const Color(0xFFF7B731),
        'screen': const DemandPredictionScreen(),
      },
      {
        'id': 'allocation',
        'title': l10n.translate('allocation_prediction'),
        'desc': l10n.translate('allocation_prediction_desc'),
        'icon': Icons.pie_chart_outline,
        'color': darkGreen,
        'screen': const AllocationPredictionScreen(),
      },
      {
        'id': 'irrigation',
        'title': l10n.translate('smart_irrigation'),
        'desc': l10n.translate('irrigation_desc'),
        'icon': Icons.water_drop_outlined,
        'color': Colors.blue,
        'screen': const ComingSoonPredictionScreen(
          titleKey: 'smart_irrigation',
          detailKey: 'irrigation_desc',
        ),
        'isComingSoon': true,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: models.length,
      itemBuilder: (context, index) {
        final model = models[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => model['screen'] as Widget),
              );
            },
            child: _buildFeatureCard(
              icon: model['icon'] as IconData,
              title: model['title'] as String,
              description: model['desc'] as String,
              color: model['color'] as Color,
              isActionable: true,
              isNew: false,
              isComingSoon: model['isComingSoon'] == true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssistantTab(AppLocalizations l10n, Color darkGreen) {
    const primaryGreen = Color(0xFF00C897);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildComingSoonBanner(l10n, primaryGreen),
                const SizedBox(height: 24),
                Text(
                  l10n.translate('smart_farming_assistant'),
                  style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: darkGreen),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.translate('smart_assistant_desc'),
                  style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[700], height: 1.5),
                ),
                const SizedBox(height: 32),
                
                _buildChatMessage(l10n.translate('msg_tomato'), false, primaryGreen),
                const SizedBox(height: 12),
                _buildChatMessage(l10n.translate('msg_cucumber'), false, primaryGreen),
                
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l10n.translate('agentic_ai_soon'),
                      style: GoogleFonts.cairo(color: Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.image_outlined, color: Colors.grey), onPressed: () {}),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F4),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    enabled: false,
                    style: GoogleFonts.cairo(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: l10n.translate('ai_assistant'),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: true,
                      hintStyle: GoogleFonts.cairo(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showVoiceAssistant,
                child: CircleAvatar(
                  backgroundColor: darkGreen.withOpacity(0.1),
                  child: Icon(Icons.mic_none, color: darkGreen),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatMessage(String text, bool isUser, Color color) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))],
          border: isUser ? null : Border.all(color: Colors.grey.shade100),
        ),
        child: Text(
          text,
          style: GoogleFonts.cairo(fontSize: 14, color: isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon, 
    required String title, 
    required String description, 
    required Color color,
    bool isActionable = false,
    bool isNew = false,
    bool isComingSoon = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isActionable ? Border.all(color: color.withOpacity(0.1), width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: isActionable ? color.withOpacity(0.05) : Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title, 
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: const Color(0xFF1A233A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isComingSoon) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                        child: Text("SOON", style: GoogleFonts.cairo(color: Colors.grey[700], fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ] else if (isNew) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF00C897), borderRadius: BorderRadius.circular(10)),
                        child: Text("NEW", style: GoogleFonts.cairo(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description, 
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[600], height: 1.3), 
                  maxLines: 2, 
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isActionable && !isComingSoon)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withOpacity(0.5)),
            ),
        ],
      ),
    );
  }

  Widget _buildComingSoonBanner(AppLocalizations l10n, Color primaryGreen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: primaryGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF00C897)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.translate('coming_soon'),
              style: GoogleFonts.cairo(color: const Color(0xFF005E4D), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
