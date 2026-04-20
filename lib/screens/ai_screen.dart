import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_localizations.dart';
import 'profit_prediction_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const darkGreen = Color(0xFF005E4D);
    const primaryGreen = Color(0xFF00C897);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: primaryGreen,
              unselectedLabelColor: Colors.grey,
              indicatorColor: primaryGreen,
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
                _buildPredictionsTab(l10n, darkGreen, primaryGreen),
                _buildAssistantTab(l10n, darkGreen, primaryGreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionsTab(AppLocalizations l10n, Color darkGreen, Color primaryGreen) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfitPredictionScreen()),
              );
            },
            child: _buildFeatureCard(
              icon: Icons.monetization_on_outlined,
              title: l10n.translate('profit_prediction'),
              description: l10n.translate('predictions_desc'),
              color: primaryGreen,
              isActionable: true,
            ),
          ),
          const SizedBox(height: 16),
          _buildComingSoonBanner(l10n, primaryGreen),
          const SizedBox(height: 16),
          _buildFeatureCard(
            icon: Icons.trending_up,
            title: l10n.translate('market_intelligence'),
            description: "Advanced trend analysis for local markets.",
            color: darkGreen,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            icon: Icons.psychology,
            title: l10n.translate('ai_predictions'),
            description: l10n.translate('crop_yield_prediction'),
            color: primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantTab(AppLocalizations l10n, Color darkGreen, Color primaryGreen) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildComingSoonBanner(l10n, primaryGreen),
                const SizedBox(height: 24),
                _buildFeatureCard(
                  icon: Icons.record_voice_over,
                  title: l10n.translate('voice_mode'),
                  description: l10n.translate('voice_mode_desc'),
                  color: darkGreen,
                ),
                const SizedBox(height: 16),
                _buildFeatureCard(
                  icon: Icons.image_search,
                  title: l10n.translate('image_analysis'),
                  description: l10n.translate('image_analysis_desc'),
                  color: primaryGreen,
                ),
                const SizedBox(height: 16),
                _buildFeatureCard(
                  icon: Icons.lightbulb_outline,
                  title: l10n.translate('personalized_advice'),
                  description: l10n.translate('assistant_desc'),
                  color: const Color(0xFF1A233A),
                ),
              ],
            ),
          ),
        ),
        // Mock input area
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
              CircleAvatar(
                backgroundColor: primaryGreen.withOpacity(0.1),
                child: Icon(Icons.mic_none, color: primaryGreen),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon, 
    required String title, 
    required String description, 
    required Color color,
    bool isActionable = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isActionable ? Border.all(color: color.withOpacity(0.3), width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (isActionable) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                        child: Text("NEW", style: GoogleFonts.cairo(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                Text(description, style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (isActionable) Icon(Icons.arrow_forward_ios, size: 14, color: color),
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
