import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'db.dart';
import 'models.dart';
import 'repository.dart';

/// SQLite 实现。每次写操作都往 sync_queue 记一笔脏标记，
/// 将来接远端时增量推送只需要读那张表，不用全量比对。
class SqfliteRepository implements FitnessRepository {
  final AppDatabase _db;
  final SyncAdapter _sync;

  SqfliteRepository({AppDatabase? db, SyncAdapter? sync})
      : _db = db ?? AppDatabase(),
        _sync = sync ?? NoopSyncAdapter();

  Future<Database> get _x => _db.database;

  Future<void> _touch(String entity, int entityId, String op) async {
    final db = await _x;
    await db.insert('sync_queue', {
      'entity': entity,
      'entity_id': entityId,
      'op': op,
      'queued_at': DateTime.now().toIso8601String(),
    });
    await _sync.markDirty(entity, entityId, op);
  }

  /* ------------------------------------------------------------ 计划 */

  @override
  Future<List<Plan>> listPlans() async {
    final db = await _x;
    final rows = await db.query('plans', orderBy: 'created_at DESC');
    return rows.map(Plan.fromMap).toList();
  }

  @override
  Future<Plan?> getPlan(int id) async {
    final db = await _x;
    final rows = await db.query('plans', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Plan.fromMap(rows.first);
  }

  @override
  Future<Plan> createPlan(Plan plan) async {
    final db = await _x;
    final id = await db.insert('plans', plan.toMap());
    await _touch('plans', id, 'insert');
    return Plan(
      id: id,
      title: plan.title,
      weeks: plan.weeks,
      startDate: plan.startDate,
      status: plan.status,
      planJson: plan.planJson,
      createdAt: plan.createdAt,
    );
  }

  @override
  Future<void> updatePlan(Plan plan) async {
    if (plan.id == null) return;
    final db = await _x;
    await db.update('plans', plan.toMap(), where: 'id = ?', whereArgs: [plan.id]);
    await _touch('plans', plan.id!, 'update');
  }

  @override
  Future<void> deletePlan(int id) async {
    final db = await _x;
    await db.update('workout_sessions', {'plan_id': null},
        where: 'plan_id = ?', whereArgs: [id]);
    await db.delete('plans', where: 'id = ?', whereArgs: [id]);
    await _touch('plans', id, 'delete');
  }

  /* ------------------------------------------------------------ 训练 */

  @override
  Future<WorkoutSession> createSession(WorkoutSession session) async {
    final db = await _x;
    final id = await db.insert('workout_sessions', session.toMap());
    await _touch('workout_sessions', id, 'insert');
    return WorkoutSession(
      id: id,
      planId: session.planId,
      dayId: session.dayId,
      dayTitle: session.dayTitle,
      version: session.version,
      status: session.status,
      performedOn: session.performedOn,
      durationMin: session.durationMin,
      note: session.note,
    );
  }

  @override
  Future<void> updateSession(WorkoutSession session) async {
    if (session.id == null) return;
    final db = await _x;
    await db.update('workout_sessions', session.toMap(),
        where: 'id = ?', whereArgs: [session.id]);
    await _touch('workout_sessions', session.id!, 'update');
  }

  @override
  Future<List<WorkoutSession>> listSessions({String? from, String? to, int? limit}) async {
    final db = await _x;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) { where.add('performed_on >= ?'); args.add(from); }
    if (to != null) { where.add('performed_on <= ?'); args.add(to); }
    final rows = await db.query(
      'workout_sessions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'performed_on DESC, id DESC',
      limit: limit,
    );
    return rows.map(WorkoutSession.fromMap).toList();
  }

  @override
  Future<void> deleteSession(int id) async {
    final db = await _x;
    await db.delete('set_logs', where: 'session_id = ?', whereArgs: [id]);
    await db.delete('workout_sessions', where: 'id = ?', whereArgs: [id]);
    await _touch('workout_sessions', id, 'delete');
  }

  @override
  Future<List<SetLog>> listSets(int sessionId) async {
    final db = await _x;
    final rows = await db.query('set_logs',
        where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'set_index ASC');
    return rows.map(SetLog.fromMap).toList();
  }

  @override
  Future<void> insertSets(List<SetLog> sets) async {
    if (sets.isEmpty) return;
    final db = await _x;
    final batch = db.batch();
    for (final s in sets) {
      batch.insert('set_logs', s.toMap());
    }
    await batch.commit(noResult: true);
    await _touch('set_logs', sets.first.sessionId, 'insert');
  }

  @override
  Future<List<ExerciseHistory>> historyForExercise(String? key,
      {String? fallbackName}) async {
    final db = await _x;
    final rows = key != null && key.isNotEmpty
        ? await db.query('set_logs', where: 'exercise_key = ?', whereArgs: [key])
        : await db.query('set_logs',
            where: 'exercise_name = ?', whereArgs: [fallbackName]);

    if (rows.isEmpty) return const [];

    final sessionIds = rows.map((r) => r['session_id'] as int).toSet().toList();
    final placeholders = List.filled(sessionIds.length, '?').join(',');
    final sessions = await db.rawQuery(
      'SELECT id, performed_on FROM workout_sessions WHERE id IN ($placeholders)',
      sessionIds,
    );
    final dateOf = <int, String>{
      for (final s in sessions) s['id'] as int: s['performed_on'] as String,
    };

    final grouped = <String, List<SetLog>>{};
    for (final r in rows) {
      final date = dateOf[r['session_id'] as int];
      if (date == null) continue;
      grouped.putIfAbsent(date, () => []).add(SetLog.fromMap(r));
    }
    final keys = grouped.keys.toList()..sort();
    return keys.map((d) => ExerciseHistory(date: d, sets: grouped[d]!)).toList();
  }

  /* ------------------------------------------------------------ 身体 */

  @override
  Future<List<BodyMetric>> listBodyMetrics() async {
    final db = await _x;
    final rows = await db.query('body_metrics', orderBy: 'recorded_on ASC', limit: 500);
    return rows.map(BodyMetric.fromMap).toList();
  }

  @override
  Future<void> upsertBodyMetric(BodyMetric metric) async {
    final db = await _x;
    final id = await db.insert(
      'body_metrics',
      metric.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _touch('body_metrics', id, 'upsert');
  }

  @override
  Future<void> deleteBodyMetric(int id) async {
    final db = await _x;
    await db.delete('body_metrics', where: 'id = ?', whereArgs: [id]);
    await _touch('body_metrics', id, 'delete');
  }

  /* ------------------------------------------------------------ 营养 */

  @override
  Future<List<NutritionTarget>> listNutritionTargets() async {
    final db = await _x;
    final rows = await db.query('nutrition_targets');
    return rows.map(NutritionTarget.fromMap).toList();
  }

  @override
  Future<void> upsertNutritionTarget(NutritionTarget target) async {
    final db = await _x;
    final id = await db.insert(
      'nutrition_targets',
      target.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _touch('nutrition_targets', id, 'upsert');
  }

  @override
  Future<List<Meal>> listMeals(String date) async {
    final db = await _x;
    final rows = await db.query('meals',
        where: 'eaten_on = ?', whereArgs: [date], orderBy: 'created_at ASC');
    return rows.map(Meal.fromMap).toList();
  }

  @override
  Future<void> addMeal(Meal meal) async {
    final db = await _x;
    final id = await db.insert('meals', meal.toMap());
    await _touch('meals', id, 'insert');
  }

  @override
  Future<void> deleteMeal(int id) async {
    final db = await _x;
    await db.delete('meals', where: 'id = ?', whereArgs: [id]);
    await _touch('meals', id, 'delete');
  }

  /* ------------------------------------------------------------ 复盘 */

  @override
  Future<List<WeeklyReview>> listWeeklyReviews({int limit = 30}) async {
    final db = await _x;
    final rows = await db.query('weekly_reviews',
        orderBy: 'week_start DESC', limit: limit);
    return rows.map(WeeklyReview.fromMap).toList();
  }

  @override
  Future<void> upsertWeeklyReview(WeeklyReview review) async {
    final db = await _x;
    final id = await db.insert(
      'weekly_reviews',
      review.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _touch('weekly_reviews', id, 'upsert');
  }

  /* ------------------------------------------------------------ 导出导入 */

  static const _tables = [
    'plans',
    'workout_sessions',
    'set_logs',
    'body_metrics',
    'nutrition_targets',
    'meals',
    'weekly_reviews',
  ];

  @override
  Future<Map<String, dynamic>> exportAll() async {
    final db = await _x;
    final out = <String, dynamic>{
      'format': 'fitness-desk-export',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'data': <String, dynamic>{},
    };
    final data = out['data'] as Map<String, dynamic>;
    for (final t in _tables) {
      data[t] = await db.query(t, orderBy: 'id ASC');
    }
    return out;
  }

  @override
  Future<void> importAll(Map<String, dynamic> payload) async {
    if (payload['format'] != 'fitness-desk-export') {
      throw FormatException('不是训练台导出的文件格式');
    }
    final data = payload['data'];
    if (data is! Map) throw const FormatException('导出文件缺少 data 字段');

    final db = await _x;
    await db.transaction((txn) async {
      for (final t in _tables) {
        final rows = data[t];
        if (rows is! List) continue;
        await txn.delete(t);
        for (final row in rows) {
          if (row is! Map) continue;
          await txn.insert(t, Map<String, dynamic>.from(row));
        }
      }
      await txn.delete('sync_queue');
    });
  }
}

/// 把导出内容序列化成可复制的文本
String encodeExport(Map<String, dynamic> payload) =>
    const JsonEncoder.withIndent('  ').convert(payload);

Map<String, dynamic> decodeExport(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map) throw const FormatException('不是合法的 JSON 对象');
  return Map<String, dynamic>.from(decoded);
}
