import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_localizations.dart';
import '../services/supabase_service.dart';
import 'profile_screen.dart';
import 'home_dashboard.dart';
import 'statistics_page.dart';
import 'notifications_screen.dart';
import 'calendar_screen.dart';
import 'ai_screen.dart';

// Global key to access HomeScreen state from anywhere
final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

class HomeScreen extends StatefulWidget {
  final Function(Locale) onLanguageChange;
  const HomeScreen({super.key, required this.onLanguageChange});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _service = SupabaseService();
  int _selectedIndex = 0;
  int _unreadNotifications = 0;
  Key _refreshKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _checkNotifications();
  }

  void refreshApp() {
    if (mounted) {
      setState(() {
        _refreshKey = UniqueKey();
        _checkNotifications();
      });
    }
  }

  Future<void> _checkNotifications() async {
    final user = _service.currentUser;
    if (user != null) {
      try {
        final notifications = await _service.getNotifications(user.id);
        if (mounted) {
          setState(() {
            _unreadNotifications = notifications.where((n) => !n.isRead).length;
          });
        }
      } catch (e) {
        debugPrint('Error checking notifications: $e');
      }
    }
  }

  void _onViewPlans() {
    setState(() {
      _selectedIndex = 3; // Index for StatisticsPage
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const darkGreen = Color(0xFF005E4D);
    const primaryGreen = Color(0xFF00C897);

    final List<Widget> screens = [
      HomeDashboard(onViewPlans: _onViewPlans),
      const CalendarScreen(),
      const AiScreen(),
      const StatisticsPage(),
      const PlaceholderScreen(title: 'jobs'),
    ];

    void goToProfile() {
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => ProfileScreen(onLanguageChange: widget.onLanguageChange))
      );
    }

    void goToNotifications() async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
      _checkNotifications(); // Refresh count when coming back
    }

    // Explicitly layout Left and Right
    Widget profileBtn = IconButton(
      icon: const Icon(Icons.account_circle_outlined, color: darkGreen, size: 28), 
      onPressed: goToProfile
    );

    Widget notificationBtn = _buildNotificationBtn(goToNotifications, darkGreen, false);

    Widget headerButtons = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          Align(alignment: Alignment.centerLeft, child: profileBtn),
          Align(alignment: Alignment.centerRight, child: notificationBtn),
        ],
      ),
    );

    final bool isAiSelected = _selectedIndex == 2;

    return Scaffold(
      key: _refreshKey,
      appBar: _selectedIndex == 0 
        ? null 
        : AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: headerButtons,
          ),
      body: Stack(
        children: [
          IndexedStack(
            key: ValueKey(_refreshKey), // Force IndexedStack rebuild
            index: _selectedIndex,
            children: screens,
          ),
          if (_selectedIndex == 0) ...[
            Positioned(
              top: 50,
              left: 20,
              child: _buildFloatingBtn(Icons.account_circle_outlined, goToProfile, darkGreen),
            ),
            Positioned(
              top: 50,
              right: 20,
              child: _buildNotificationBtn(goToNotifications, darkGreen, true),
            ),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: 70,
        width: 70,
        margin: const EdgeInsets.only(top: 30),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: isAiSelected ? [
            BoxShadow(color: primaryGreen.withOpacity(0.6), blurRadius: 25, spreadRadius: 8),
            BoxShadow(color: primaryGreen.withOpacity(0.3), blurRadius: 45, spreadRadius: 15),
          ] : [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => setState(() => _selectedIndex = 2),
          backgroundColor: isAiSelected ? primaryGreen : darkGreen,
          shape: const CircleBorder(),
          elevation: 0,
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 35),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: primaryGreen,
          unselectedItemColor: Colors.grey,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: GoogleFonts.cairo(fontSize: 10),
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.grass_outlined), activeIcon: const Icon(Icons.grass), label: l10n.translate('home')),
            BottomNavigationBarItem(icon: const Icon(Icons.calendar_month_outlined), activeIcon: const Icon(Icons.calendar_month), label: l10n.translate('calendar')),
            const BottomNavigationBarItem(icon: Opacity(opacity: 0, child: Icon(Icons.circle)), label: ''),
            BottomNavigationBarItem(icon: const Icon(Icons.bar_chart_outlined), activeIcon: const Icon(Icons.bar_chart), label: l10n.translate('statistics')),
            BottomNavigationBarItem(icon: const Icon(Icons.work_outline), activeIcon: const Icon(Icons.work), label: l10n.translate('jobs')),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingBtn(IconData icon, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _buildNotificationBtn(VoidCallback onTap, Color color, bool isFloating) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          isFloating 
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(Icons.notifications_none, color: color, size: 28),
              )
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(Icons.notifications_none, color: color, size: 28),
              ),
          if (_unreadNotifications > 0)
            Positioned(
              top: isFloating ? -2 : 4,
              right: isFloating ? -2 : 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  _unreadNotifications.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.translate(title),
            style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF005E4D)),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.translate('coming_soon'),
            style: GoogleFonts.cairo(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
