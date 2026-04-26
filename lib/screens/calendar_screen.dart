import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/crop.dart';
import '../models/reminder.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';
import 'add_task_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _service = SupabaseService();
  final _supabase = Supabase.instance.client;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Task> _tasksForSelectedDay = [];
  Map<DateTime, List<Task>> _allTasks = {};
  List<Crop> _crops = [];
  Map<String, String> _taskReminders = {}; // taskId -> formattedTime
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchAllTasks();
    _processPendingReminders();
  }

  Future<void> _fetchAllTasks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _service.currentUser;
      if (user != null) {
        final tasksResponse = await _service.getAllUserTasks(user.id);
        final cropsResponse = await _service.getCrops();
        
        // Fetch reminders to show times on cards
        final remindersResponse = await _supabase
            .from('reminders')
            .select()
            .eq('is_sent', false); // Only pending ones generally, or all if you prefer
        
        Map<String, String> reminderMap = {};
        for (var r in remindersResponse) {
          final time = DateTime.parse(r['reminder_time']).toLocal();
          reminderMap[r['task_id'].toString()] = DateFormat.Hm().format(time);
        }

        Map<DateTime, List<Task>> taskMap = {};
        for (var task in tasksResponse) {
          final date = DateTime(task.taskDate.year, task.taskDate.month, task.taskDate.day);
          taskMap.putIfAbsent(date, () => []).add(task);
        }

        if (mounted) {
          setState(() {
            _allTasks = taskMap;
            _crops = cropsResponse;
            _taskReminders = reminderMap;
            _tasksForSelectedDay = _allTasks[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching all tasks: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processPendingReminders() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    await _service.processReminders(l10n);
  }

  Future<void> _toggleTask(Task task) async {
    try {
      await _service.toggleTaskCompletion(task.id!, !task.isCompleted);
      await _fetchAllTasks();
    } catch (e) {
      debugPrint('Error toggling task: $e');
    }
  }

  Future<void> _deleteTask(Task task) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.translate('confirm_delete'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text(l10n.translate('delete_task_confirm'), style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.translate('cancel'), style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.translate('delete'), style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteTask(task.id!);
        await _fetchAllTasks();
      } catch (e) {
        debugPrint('Error deleting task: $e');
      }
    }
  }

  String _getTranslatedTitle(Task task, AppLocalizations l10n) {
    if (task.title == 'plant_crop' || task.title == 'harvest_crop') {
      final cropId = int.tryParse(task.description ?? '') ?? 0;
      final crop = _crops.firstWhere((c) => c.id == cropId, orElse: () => _crops.isNotEmpty ? _crops.first : Crop(id: 0, nameEn: 'Crop', nameAr: 'محصول', emoji: '🌿', avgYield: 0, categoryId: 0));
      final cropName = l10n.locale.languageCode == 'ar' ? crop.nameAr : crop.nameEn;
      return l10n.translate(task.title).replaceAll('{crop}', cropName);
    }
    return task.title;
  }

  String? _getTranslatedDescription(Task task, AppLocalizations l10n) {
    if (task.title == 'plant_crop' || task.title == 'harvest_crop') {
      final cropId = int.tryParse(task.description ?? '') ?? 0;
      final crop = _crops.firstWhere((c) => c.id == cropId, orElse: () => _crops.isNotEmpty ? _crops.first : Crop(id: 0, nameEn: 'Crop', nameAr: 'محصول', emoji: '🌿', avgYield: 0, categoryId: 0));
      final cropName = l10n.locale.languageCode == 'ar' ? crop.nameAr : crop.nameEn;
      return l10n.translate('${task.title}_desc').replaceAll('{crop}', cropName);
    }
    return task.description;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    const darkGreen = AppTheme.primary;
    const taskMarkerYellow = Colors.orangeAccent;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _fetchAllTasks,
        color: darkGreen,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: TableCalendar(
                locale: locale,
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) => _allTasks[DateTime(day.year, day.month, day.day)] ?? [],
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _tasksForSelectedDay = _allTasks[DateTime(selectedDay.year, selectedDay.month, selectedDay.day)] ?? [];
                  });
                },
                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(color: darkGreen, shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(color: darkGreen.withOpacity(0.1), shape: BoxShape.circle),
                  todayTextStyle: const TextStyle(color: darkGreen, fontWeight: FontWeight.bold),
                  markerDecoration: const BoxDecoration(color: taskMarkerYellow, shape: BoxShape.circle),
                  markersMaxCount: 3,
                  outsideDaysVisible: false,
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18, color: darkGreen),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    l10n.translate('tasks'),
                    style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkGreen),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('EEEE, d MMMM').format(_selectedDay!),
                    style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: darkGreen))
                  : _tasksForSelectedDay.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.event_available_outlined, size: 64, color: Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.translate('no_tasks'),
                                    style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _tasksForSelectedDay.length,
                          itemBuilder: (context, index) {
                            final task = _tasksForSelectedDay[index];
                            final title = _getTranslatedTitle(task, l10n);
                            final desc = _getTranslatedDescription(task, l10n);
                            final reminderTime = _taskReminders[task.id];

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: task.isCompleted ? Colors.transparent : darkGreen.withOpacity(0.1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        color: task.isCompleted ? Colors.grey[300] : darkGreen,
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () => _toggleTask(task),
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: task.isCompleted ? Colors.grey : darkGreen,
                                                      width: 2,
                                                    ),
                                                    color: task.isCompleted ? Colors.grey : Colors.transparent,
                                                  ),
                                                  child: task.isCompleted
                                                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      title,
                                                      style: GoogleFonts.cairo(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: task.isCompleted ? Colors.grey : const Color(0xFF1A233A),
                                                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                                      ),
                                                    ),
                                                    if (desc != null && desc.isNotEmpty)
                                                      Text(
                                                        desc,
                                                        style: GoogleFonts.cairo(
                                                          fontSize: 13,
                                                          color: Colors.grey[600],
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    if (reminderTime != null)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 8),
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.notifications_active_outlined, size: 14, color: taskMarkerYellow),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              '${l10n.translate('reminder')}: $reminderTime',
                                                              style: GoogleFonts.cairo(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.bold,
                                                                color: taskMarkerYellow,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  if (task.plantingPlanId != null)
                                                    Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: darkGreen.withOpacity(0.05),
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: const Icon(Icons.grass, color: darkGreen, size: 18),
                                                    ),
                                                  IconButton(
                                                    icon: Icon(Icons.delete_outline, color: Colors.red.withOpacity(0.7), size: 22),
                                                    onPressed: () => _deleteTask(task),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddTaskScreen(initialDate: _selectedDay ?? DateTime.now())),
          );
          if (result == true) await _fetchAllTasks();
        },
        backgroundColor: darkGreen,
        icon: const Icon(Icons.add_task, color: Colors.white),
        label: Text(l10n.translate('add_task'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}
