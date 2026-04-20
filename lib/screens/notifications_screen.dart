import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/notification.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = SupabaseService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final user = _service.currentUser;
      if (user != null) {
        final notifications = await _service.getNotifications(user.id);
        if (mounted) setState(() => _notifications = notifications);
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await _service.markNotificationAsRead(notification.id!);
      _fetchNotifications();
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const darkGreen = Color(0xFF005E4D);
    const primaryGreen = Color(0xFF00C897);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('notifications'),
          style: GoogleFonts.cairo(color: darkGreen, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkGreen),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_none, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        l10n.translate('no_notifications'),
                        style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: notification.isRead ? Colors.white : const Color(0xFFF0FFF4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          onTap: () => _markAsRead(notification),
                          leading: CircleAvatar(
                            backgroundColor: notification.isRead ? Colors.grey.shade200 : primaryGreen.withOpacity(0.2),
                            child: Icon(
                              notification.isRead ? Icons.notifications_none : Icons.notifications_active,
                              color: notification.isRead ? Colors.grey : primaryGreen,
                            ),
                          ),
                          title: Text(
                            notification.title,
                            style: GoogleFonts.cairo(
                              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                              color: darkGreen,
                            ),
                          ),
                          subtitle: Text(
                            notification.message,
                            style: GoogleFonts.cairo(fontSize: 13),
                          ),
                          trailing: notification.isRead 
                            ? null 
                            : Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
