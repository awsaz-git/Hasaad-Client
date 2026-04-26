import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../models/governorate.dart';
import '../models/crop.dart';
import '../models/category.dart';
import '../models/planting_plan.dart';
import '../models/crop_demand.dart';
import '../models/crop_supply.dart';
import '../models/task.dart';
import '../models/reminder.dart';
import '../models/notification.dart';
import '../models/job.dart';
import '../models/crop_financial.dart';
import '../utils/app_localizations.dart';
import 'notification_service.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  String _nationalIdToEmail(String nationalId) => '$nationalId@hasaad.app';

  Future<AuthResponse?> signIn(String nationalId, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: _nationalIdToEmail(nationalId),
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      print('AuthException in signIn: ${e.message}');
      return null;
    } catch (e) {
      print('Unexpected error in signIn: $e');
      return null;
    }
  }

  Future<AuthResponse?> signUp(String nationalId, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: _nationalIdToEmail(nationalId),
        password: password,
      );
      return response;
    } catch (e) {
      print('Error in signUp: $e');
      rethrow;
    }
  }

  Future<Profile?> getProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (response == null) return null;
      return Profile.fromJson(response);
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }

  Future<void> createProfile(Profile profile) async {
    await _supabase.from('profiles').insert(profile.toJson());
  }

  Future<List<Governorate>> getGovernorates() async {
    try {
      final response = await _supabase.from('governorates').select();
      return (response as List).map((json) => Governorate.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching governorates: $e');
      return [];
    }
  }

  Future<List<Crop>> getCrops() async {
    final response = await _supabase.from('crops').select();
    return (response as List).map((json) => Crop.fromJson(json)).toList();
  }

  Future<List<CropCategory>> getCategories() async {
    final response = await _supabase.from('crop_categories').select();
    return (response as List).map((json) => CropCategory.fromJson(json)).toList();
  }

  Future<List<PlantingPlan>> getUserPlantingPlans(String userId) async {
    final response = await _supabase.from('planting_plans').select().eq('farmer_id', userId).order('created_at', ascending: false);
    return (response as List).map((json) => PlantingPlan.fromJson(json)).toList();
  }

  // --- Planting Plans, Supply, and Auto-Tasks ---

  Future<double> getCropAvgYield(int cropId) async {
    final response = await _supabase
        .from('crops')
        .select('avg_yield_per_donum')
        .eq('id', cropId)
        .single();
    return (response['avg_yield_per_donum'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> addPlantingPlan(PlantingPlan plan) async {
    try {
      final planResponse = await _supabase.from('planting_plans').insert(plan.toJson()).select().single();
      final insertedPlanId = planResponse['id'].toString();

      await _updateCropSupply(
        cropId: plan.cropId,
        governorateId: plan.governorateId,
        areaDelta: plan.areaDonums,
        yieldDelta: plan.estimatedYieldTons ?? 0.0,
        countDelta: 1,
      );

      final crops = await getCrops();
      final crop = crops.firstWhere((c) => c.id == plan.cropId);
      
      // Create localized tasks for planting and harvesting
      await addTask(Task(
        farmerId: plan.farmerId,
        title: 'plant_crop', 
        description: crop.id.toString(),
        taskDate: plan.plantingDate,
        plantingPlanId: insertedPlanId,
      ), reminderTime: DateTime(plan.plantingDate.year, plan.plantingDate.month, plan.plantingDate.day, 8, 0));

      await addTask(Task(
        farmerId: plan.farmerId,
        title: 'harvest_crop',
        description: crop.id.toString(),
        taskDate: plan.harvestDate,
        plantingPlanId: insertedPlanId,
      ), reminderTime: DateTime(plan.harvestDate.year, plan.harvestDate.month, plan.harvestDate.day, 8, 0));
    } catch (e) {
      print('Postgres error in addPlantingPlan: $e');
      rethrow;
    }
  }

  Future<void> updatePlanStatusWithSupply(PlantingPlan plan, String newStatus) async {
    if (plan.status == newStatus) return;

    try {
      await _supabase.from('planting_plans').update({'status': newStatus}).eq('id', plan.id!);

      if (plan.status == 'active' && (newStatus == 'cancelled' || newStatus == 'harvested')) {
        await _updateCropSupply(
          cropId: plan.cropId,
          governorateId: plan.governorateId,
          areaDelta: -plan.areaDonums,
          yieldDelta: -(plan.estimatedYieldTons ?? 0.0),
          countDelta: -1,
        );
      }
    } catch (e) {
      print('Postgres error in updatePlanStatusWithSupply: $e');
      rethrow;
    }
  }

  Future<void> _updateCropSupply({
    required int cropId,
    required int governorateId,
    required double areaDelta,
    required double yieldDelta,
    required int countDelta,
  }) async {
    final today = DateTime.now().toIso8601String().split('T')[0];

    final existing = await _supabase
        .from('crop_supply')
        .select()
        .eq('crop_id', cropId)
        .eq('governorate_id', governorateId)
        .eq('supply_date', today)
        .maybeSingle();

    if (existing != null) {
      await _supabase.from('crop_supply').update({
        'total_area_donums': (existing['total_area_donums'] as num).toDouble() + areaDelta,
        'total_estimated_tons': (existing['total_estimated_tons'] as num).toDouble() + yieldDelta,
        'active_plans_count': (existing['active_plans_count'] as int) + countDelta,
      }).eq('id', existing['id']);
    } else {
      if (countDelta > 0) {
        await _supabase.from('crop_supply').insert({
          'crop_id': cropId,
          'governorate_id': governorateId,
          'total_area_donums': areaDelta,
          'total_estimated_tons': yieldDelta,
          'active_plans_count': countDelta,
          'supply_date': today,
        });
      }
    }
  }

  // --- Tasks & Reminders ---

  Future<List<Task>> getAllUserTasks(String userId) async {
    final response = await _supabase
        .from('tasks')
        .select()
        .eq('farmer_id', userId);
    return (response as List).map((json) => Task.fromJson(json)).toList();
  }

  Future<List<Task>> getTasks(String userId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final response = await _supabase
        .from('tasks')
        .select()
        .eq('farmer_id', userId)
        .eq('task_date', dateStr)
        .order('created_at');
    return (response as List).map((json) => Task.fromJson(json)).toList();
  }

  Future<void> addTask(Task task, {DateTime? reminderTime}) async {
    final response = await _supabase.from('tasks').insert(task.toJson()).select().single();
    final taskId = response['id'].toString();

    if (reminderTime != null) {
      await _supabase.from('reminders').insert({
        'task_id': taskId,
        'reminder_time': reminderTime.toIso8601String(),
        'is_sent': false,
      });
    }
  }

  Future<void> deleteTask(String taskId) async {
    await _supabase.from('tasks').delete().eq('id', taskId);
  }

  Future<void> toggleTaskCompletion(String taskId, bool isCompleted) async {
    await _supabase.from('tasks').update({'is_completed': isCompleted}).eq('id', taskId);
  }

  Future<void> processReminders(AppLocalizations l10n) async {
    final user = currentUser;
    if (user == null) return;

    final now = DateTime.now().toIso8601String();
    
    final response = await _supabase
        .from('reminders')
        .select('*, tasks!inner(*)')
        .eq('is_sent', false)
        .lte('reminder_time', now)
        .eq('tasks.farmer_id', user.id);

    final crops = await getCrops();

    for (var item in response) {
      final task = Task.fromJson(item['tasks']);
      
      String title = task.title;
      String body = task.description ?? '';

      if (task.title == 'plant_crop' || task.title == 'harvest_crop') {
        final cropId = int.tryParse(task.description ?? '') ?? 0;
        final crop = crops.firstWhere((c) => c.id == cropId, orElse: () => crops.first);
        final cropName = l10n.locale.languageCode == 'ar' ? crop.nameAr : crop.nameEn;
        
        title = l10n.translate(task.title).replaceAll('{crop}', cropName);
        body = l10n.translate('${task.title}_desc').replaceAll('{crop}', cropName);
      } else {
        title = '${l10n.translate('reminder')}: ${task.title}';
      }

      await _supabase.from('notifications').insert({
        'farmer_id': user.id,
        'title': title,
        'message': body,
        'is_read': false,
      });

      await NotificationService().showNotification(
        title: title,
        body: body,
      );

      await _supabase.from('reminders').update({'is_sent': true}).eq('id', item['id']);
    }
  }

  // --- Notifications ---

  Future<List<AppNotification>> getNotifications(String userId) async {
    final response = await _supabase
        .from('notifications')
        .select()
        .eq('farmer_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((json) => AppNotification.fromJson(json)).toList();
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _supabase.from('notifications').update({'is_read': true}).eq('id', notificationId);
  }

  // --- Market Data ---

  Future<Map<int, double>> getCropSupplyMap(int governorateId) async {
    final supplyTable = await _supabase.from('crop_supply').select().eq('governorate_id', governorateId);
    Map<int, double> supplyMap = {};
    for (var item in supplyTable) {
      supplyMap[item['crop_id']] = (item['total_estimated_tons'] as num).toDouble();
    }
    return supplyMap;
  }

  Future<Map<int, double>> getTotalCropSupplyMap() async {
    final supplyTable = await _supabase.from('crop_supply').select();
    Map<int, double> totalSupplyMap = {};
    for (var item in supplyTable) {
      int cropId = item['crop_id'];
      double supply = (item['total_estimated_tons'] as num).toDouble();
      totalSupplyMap[cropId] = (totalSupplyMap[cropId] ?? 0) + supply;
    }
    return totalSupplyMap;
  }

  Future<List<CropSupply>> getDetailedCropSupply(int cropId) async {
    final response = await _supabase.from('crop_supply').select().eq('crop_id', cropId);
    return (response as List).map((json) => CropSupply.fromJson(json)).toList();
  }

  Future<CropDemand?> getCropDemand(int cropId) async {
    final response = await _supabase.from('crop_demand').select().eq('crop_id', cropId).maybeSingle();
    if (response == null) return null;
    return CropDemand.fromJson(response);
  }

  Future<Map<int, double>> getCropDemandMap() async {
    final response = await _supabase.from('crop_demand').select();
    Map<int, double> demandMap = {};
    for (var item in response) {
      demandMap[item['crop_id']] = (item['demand_tons'] as num).toDouble();
    }
    return demandMap;
  }

  // --- Jobs ---

  Future<List<Job>> getMyJobs(String userId) async {
    final response = await _supabase
        .from('jobs')
        .select()
        .eq('farmer_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((json) => Job.fromJson(json)).toList();
  }

  Future<void> createJob(Job job) async {
    await _supabase.from('jobs').insert(job.toJson());
  }

  Future<void> updateJob(Job job) async {
    await _supabase.from('jobs').update(job.toJson()).eq('id', job.id!);
  }

  Future<void> closeJob(String jobId) async {
    await _supabase.from('jobs').update({'is_active': false}).eq('id', jobId);
  }

  Future<List<JobApplicant>> getJobApplicants(String jobId) async {
    final response = await _supabase
        .from('job_applicants')
        .select()
        .eq('job_id', jobId)
        .order('created_at', ascending: false);
    return (response as List).map((json) => JobApplicant.fromJson(json)).toList();
  }

  // --- Financial Insights ---

  Future<List<CropFinancial>> getCropFinancials(String userId) async {
    final response = await _supabase
        .from('crop_financials')
        .select()
        .eq('farmer_id', userId);
    return (response as List).map((json) => CropFinancial.fromJson(json)).toList();
  }

  Future<void> upsertCropFinancial(CropFinancial financial) async {
    final existing = await _supabase
        .from('crop_financials')
        .select()
        .eq('farmer_id', financial.farmerId)
        .eq('crop_id', financial.cropId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('crop_financials')
          .update(financial.toJson())
          .eq('id', existing['id']);
    } else {
      await _supabase.from('crop_financials').insert(financial.toJson());
    }
  }

  // --- Suggestions ---

  Future<void> submitSuggestion(String userId, String title, String description) async {
    await _supabase.from('suggestions').insert({
      'farmer_id': userId,
      'title': title,
      'description': description,
    });
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;
}
