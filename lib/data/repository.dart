import 'models.dart';

/// 数据访问的抽象层。
/// 上层页面只依赖这个接口，所以以后换成远端实现（Supabase / Firebase / 自建）时，
/// 页面代码一行都不用改。
abstract class FitnessRepository {
  /* 计划 */
  Future<List<Plan>> listPlans();
  Future<Plan?> getPlan(int id);
  Future<Plan> createPlan(Plan plan);
  Future<void> updatePlan(Plan plan);
  Future<void> deletePlan(int id);

  /* 训练 */
  Future<WorkoutSession> createSession(WorkoutSession session);
  Future<void> updateSession(WorkoutSession session);
  Future<List<WorkoutSession>> listSessions({String? from, String? to, int? limit});
  Future<void> deleteSession(int id);
  Future<List<SetLog>> listSets(int sessionId);
  Future<void> insertSets(List<SetLog> sets);
  /// 某个动作的历史，按日期升序：[{date, sets}]
  Future<List<ExerciseHistory>> historyForExercise(String? key, {String? fallbackName});

  /* 身体 */
  Future<List<BodyMetric>> listBodyMetrics();
  Future<void> upsertBodyMetric(BodyMetric metric);
  Future<void> deleteBodyMetric(int id);

  /* 营养 */
  Future<List<NutritionTarget>> listNutritionTargets();
  Future<void> upsertNutritionTarget(NutritionTarget target);
  Future<List<Meal>> listMeals(String date);
  Future<void> addMeal(Meal meal);
  Future<void> deleteMeal(int id);

  /* 复盘 */
  Future<List<WeeklyReview>> listWeeklyReviews({int limit = 30});
  Future<void> upsertWeeklyReview(WeeklyReview review);

  /* 整库导出 / 导入，用于换手机或接入同步 */
  Future<Map<String, dynamic>> exportAll();
  Future<void> importAll(Map<String, dynamic> payload);
}

class ExerciseHistory {
  final String date;
  final List<SetLog> sets;
  const ExerciseHistory({required this.date, required this.sets});
}

/// 同步适配器。当前是空实现（纯本地），接远端时实现这个接口即可。
/// 本地每次写入都会往 sync_queue 记一笔，远端适配器只要读那张表就能增量推送。
abstract class SyncAdapter {
  String get name;
  bool get enabled;
  Future<void> markDirty(String entity, int entityId, String op);
  Future<int> pendingCount();
  Future<SyncResult> push();
  Future<SyncResult> pull();
}

class SyncResult {
  final bool ok;
  final int pushed;
  final int pulled;
  final String? message;

  const SyncResult({
    required this.ok,
    this.pushed = 0,
    this.pulled = 0,
    this.message,
  });
}

/// 默认实现：什么都不做。数据完全留在本机。
class NoopSyncAdapter implements SyncAdapter {
  @override
  String get name => '仅本机（未接同步）';

  @override
  bool get enabled => false;

  @override
  Future<void> markDirty(String entity, int entityId, String op) async {}

  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<SyncResult> push() async =>
      const SyncResult(ok: true, message: '当前未接入远端同步');

  @override
  Future<SyncResult> pull() async =>
      const SyncResult(ok: true, message: '当前未接入远端同步');
}
