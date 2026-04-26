import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';
import '../services/supabase_service.dart';
import 'profile_screen.dart';
import 'home_dashboard.dart';
import 'statistics_page.dart';
import 'notifications_screen.dart';
import 'calendar_screen.dart';
import 'ai_screen.dart';
import 'jobs_screen.dart';

// Global key to access HomeScreen state from anywhere
final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

class HomeScreen extends StatefulWidget {
  final Function(Locale) onLanguageChange;
  const HomeScreen({super.key, required this.onLanguageChange});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _service = SupabaseService();
  int _selectedIndex = 0;
  int _unreadNotifications = 0;
  Key _refreshKey = UniqueKey();
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _checkNotifications();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void refreshApp() {
    if (mounted) {
      setState(() {
        _refreshKey = UniqueKey();
        _checkNotifications();
      });
    }
  }

  void setSelectedIndex(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
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
    setSelectedIndex(3); // Index for StatisticsPage
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    const primaryColor = AppTheme.primary;
    const aiAccent = Color(0xFF00C897);

    final List<Widget> screens = [
      HomeDashboard(onViewPlans: _onViewPlans),
      const CalendarScreen(),
      const AiScreen(),
      const StatisticsPage(),
      const JobsScreen(),
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
      _checkNotifications();
    }

    Widget headerButtons = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTopBtn(Icons.account_circle_outlined, goToProfile, primaryColor),
          _buildNotificationBtn(goToNotifications, primaryColor),
        ],
      ),
    );

    return Scaffold(
      key: _refreshKey,
      appBar: _selectedIndex == 0 
        ? null 
        : AppBar(
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: headerButtons,
          ),
      body: Stack(
        children: [
          IndexedStack(
            key: ValueKey(_refreshKey),
            index: _selectedIndex,
            children: screens,
          ),
          if (_selectedIndex == 0) ...[
            Positioned(
              top: 50,
              left: 20,
              child: _buildFloatingBtn(Icons.account_circle_outlined, goToProfile, primaryColor),
            ),
            Positioned(
              top: 50,
              right: 20,
              child: _buildNotificationBtn(goToNotifications, primaryColor, isFloating: true),
            ),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          bool isSelected = _selectedIndex == 2;
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: isSelected ? [
                BoxShadow(
                  color: Color.lerp(
                    aiAccent.withValues(alpha: 0.3), 
                    aiAccent.withValues(alpha: 0.7), 
                    _glowController.value
                  )!,
                  blurRadius: 15 + (15 * _glowController.value),
                  spreadRadius: 4 + (6 * _glowController.value),
                )
              ] : [],
            ),
            child: child,
          );
        },
        child: FloatingActionButton(
          heroTag: 'ai_assistant_fab',
          onPressed: () => setState(() => _selectedIndex = 2),
          backgroundColor: primaryColor,
          shape: const CircleBorder(),
          elevation: _selectedIndex == 2 ? 0 : 4,
          child: Container(
            width: 60,
            height: 60,
            decoration: _selectedIndex == 2 ? const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.primary, aiAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ) : const BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
          ),
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
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey[400],
          elevation: 0,
          selectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: GoogleFonts.cairo(fontSize: 10),
          items: [
            BottomNavigationBarItem(
              icon: Opacity(
                opacity: _selectedIndex == 0 ? 1.0 : 0.6,
                child: Image.asset("assets/logo no text - nav bar.png", width: 22, height: 22, color: _selectedIndex == 0 ? primaryColor : Colors.grey[400])
              ),
              label: l10n.translate('home')
            ),
            BottomNavigationBarItem(icon: const Icon(Icons.calendar_month_outlined), activeIcon: const Icon(Icons.calendar_month), label: l10n.translate('calendar')),
            const BottomNavigationBarItem(icon: Opacity(opacity: 0, child: Icon(Icons.circle)), label: ''),
            BottomNavigationBarItem(icon: const Icon(Icons.bar_chart_outlined), activeIcon: const Icon(Icons.bar_chart), label: l10n.translate('statistics')),
            BottomNavigationBarItem(icon: const Icon(Icons.work_outline), activeIcon: const Icon(Icons.work), label: l10n.translate('jobs')),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBtn(IconData icon, VoidCallback onTap, Color color) {
    return IconButton(icon: Icon(icon, color: color, size: 28), onPressed: onTap);
  }

  Widget _buildFloatingBtn(IconData icon, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _buildNotificationBtn(VoidCallback onTap, Color color, {bool isFloating = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: isFloating ? BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
            ) : null,
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
