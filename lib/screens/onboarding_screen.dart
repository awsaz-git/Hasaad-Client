import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localizations.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final Function(Locale) onLanguageChange;
  const OnboardingScreen({super.key, required this.onLanguageChange});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'onboarding_title_1',
      'description': 'onboarding_desc_1',
      'image': 'assets/onboarding-1.avif', 
    },
    {
      'title': 'onboarding_title_2',
      'description': 'onboarding_desc_2',
      'image': 'assets/onboarding-2.avif',
    },
    {
      'title': 'onboarding_title_3',
      'description': 'onboarding_desc_3',
      'image': 'assets/onboarding-3.avif',
    },
  ];

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(onLanguageChange: widget.onLanguageChange),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const primaryColor = Color(0xFF015E54);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finishOnboarding,
                child: Text(
                  l10n.translate('skip'),
                  style: GoogleFonts.cairo(color: primaryColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) => _OnboardingPage(
                  title: l10n.translate(_onboardingData[index]['title']!),
                  description: l10n.translate(_onboardingData[index]['description']!),
                  image: _onboardingData[index]['image']!,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _onboardingData.length,
                      (index) => _buildDot(index, primaryColor),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _onboardingData.length - 1) {
                        _finishOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: Text(
                      _currentPage == _onboardingData.length - 1
                          ? l10n.translate('get_started')
                          : l10n.translate('next'),
                      style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? color : color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String title;
  final String description;
  final String image;

  const _OnboardingPage({
    required this.title,
    required this.description,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              image, 
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.image, size: 50, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF015E54),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
