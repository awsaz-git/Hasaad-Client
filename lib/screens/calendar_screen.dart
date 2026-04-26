import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/task.dart';
import '../models/crop.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';
import 'add_task_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _service = SupabaseService();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Task> _tasksForSelectedDay = [];
  Map<DateTime, List<Task>> _allTasks = {};
  List<Crop> _crops = [];
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
        
        Map<DateTime, List<Task>> taskMap = {};
        for (var task in tasksResponse) {
          final date = DateTime(task.taskDate.year, task.taskDate.month, task.taskDate.day);
          if (taskMap[date] == null) taskMap[date] = [];
          taskMap[date]!.add(task);
        }

        if (mounted) {
          setState(() {
            _allTasks = taskMap;
            _crops = cropsResponse;
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
        title: Text(l10n.translate('delete_task'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
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
    const taskMarkerYellow = Colors.orangeAccent; // Matching the yellow/orange in the suggestion icon

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchAllTasks,
        color: darkGreen, // Changed from primaryGreen (light) to darkGreen
        child: Column(
          children: [
            TableCalendar(
              locale: locale,
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: (day) {
                return _allTasks[DateTime(day.year, day.month, day.day)] ?? [];
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _tasksForSelectedDay = _allTasks[DateTime(selectedDay.year, selectedDay.month, selectedDay.day)] ?? [];
                });
              },
              calendarStyle: const CalendarStyle(
                selectedDecoration: BoxDecoration(color: darkGreen, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: Color(0xFFE0F2F1), shape: BoxShape.circle),
                todayTextStyle: TextStyle(color: darkGreen, fontWeight: FontWeight.bold),
                markerDecoration: BoxDecoration(color: taskMarkerYellow, shape: BoxShape.circle), // Changed to yellow
                markersMaxCount: 3,
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18, color: darkGreen),
              ),
            ),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: darkGreen)) // Changed to darkGreen
                  : _tasksForSelectedDay.isEmpty
                      ? ListView( // Using ListView to make it scrollable for RefreshIndicator
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            Center(
                              child: Text(
                                l10n.translate('no_tasks'),
                                style: GoogleFonts.cairo(color: Colors.grey),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _tasksForSelectedDay.length,
                          itemBuilder: (context, index) {
                            final task = _tasksForSelectedDay[index];
                            final translatedTitle = _getTranslatedTitle(task, l10n);
                            final translatedDesc = _getTranslatedDescription(task, l10n);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: Checkbox(
                                  value: task.isCompleted,
                                  activeColor: darkGreen,
                                  onChanged: (_) => _toggleTask(task),
                                ),
                                title: Text(
                                  translatedTitle,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold,
                                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                    color: task.isCompleted ? Colors.grey : darkGreen,
                                  ),
                                ),
                                subtitle: translatedDesc != null 
                                    ? Text(translatedDesc, style: GoogleFonts.cairo(fontSize: 12)) 
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (task.plantingPlanId != null) 
                                      const Icon(Icons.grass, color: darkGreen, size: 20),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () => _deleteTask(task),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddTaskScreen(initialDate: _selectedDay ?? DateTime.now())),
          );
          if (result == true) await _fetchAllTasks();
        },
        backgroundColor: darkGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
