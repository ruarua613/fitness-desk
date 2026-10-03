import 'dart:convert';

/// 数据模型。
/// 表结构与 plan-contract.json 对齐：计划正文存 plan_json，训练拆解到 workout/set 两张表，
/// 这样才能按动作查历史、算渐进。

class Plan {
  final int? id;
  final String title;
  final int weeks;
  final String startDate;
  final String status;
  final Map<String, dynamic> planJson;
  final DateTime createdAt;

  const Plan({
    this.id,
    required this.title,
    required this.weeks,
    required this.startDate,
    required this.status,
    required this.planJson,
    required this.createdAt,
  });

  String get subtitle => (planJson['plan_meta']?['subtitle'] ?? '') as String? ?? '';
  String get frequency => (planJson['plan_meta']?['frequency'] ?? '') as String? ?? '';

  List<TrainingDay> get trainingDays {
    final raw = planJson['training_days'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => TrainingDay.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<WeeklySlot> get weeklySchedule {
    final raw = planJson['weekly_schedule'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => WeeklySlot.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'weeks': weeks,
        'start_date': startDate,
        'status': status,
        'plan_json': _encodeJson(planJson),
        'created_at': createdAt.toIso8601String(),
      };

  static Plan fromMap(Map<String, dynamic> m) => Plan(
        id: m['id'] as int?,
        title: m['title'] as String? ?? '未命名计划',
        weeks: (m['weeks'] as num?)?.toInt() ?? 4,
        startDate: m['start_date'] as String? ?? '',
        status: m['status'] as String? ?? 'active',
        planJson: _decodeJson(m['plan_json']),
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class WeeklySlot {
  final int dayIndex; // 1=周一 … 7=周日
  final String label;
  final String? dayId;
  final String theme;

  const WeeklySlot({
    required this.dayIndex,
    required this.label,
    this.dayId,
    required this.theme,
  });

  factory WeeklySlot.fromJson(Map<String, dynamic> j) => WeeklySlot(
        dayIndex: (j['day_index'] as num?)?.toInt() ?? 1,
        label: j['label'] as String? ?? '',
        dayId: j['day_id'] as String?,
        theme: j['theme'] as String? ?? '',
      );
}

class Prescription {
  final int setCount;
  final String reps;
  final int repsMin;
  final int repsMax;
  final String intensity;
  final String rest;
  final int restSeconds;

  const Prescription({
    required this.setCount,
    required this.reps,
    required this.repsMin,
    required this.repsMax,
    required this.intensity,
    required this.rest,
    required this.restSeconds,
  });

  factory Prescription.fromJson(Map<String, dynamic> j) {
    final min = (j['reps_min'] as num?)?.toInt() ?? 8;
    final max = (j['reps_max'] as num?)?.toInt() ?? 12;
    return Prescription(
      setCount: (j['set_count'] as num?)?.toInt() ?? (int.tryParse('${j['sets']}') ?? 3),
      reps: j['reps'] as String? ?? '$min—$max',
      repsMin: min,
      repsMax: max,
      intensity: j['intensity'] as String? ?? 'RPE 6—7',
      rest: j['rest'] as String? ?? '90 秒',
      restSeconds: (j['rest_seconds'] as num?)?.toInt() ?? 90,
    );
  }
}

class Exercise {
  final String id;
  final String name;
  final String pattern;
  final String patternGroup;
  final String modality;
  final String equipment;
  final Prescription prescription;
  final List<String> techniqueChecks;
  final List<String> alternatives;
  final String purpose;
  final String startingInstruction;

  const Exercise({
    required this.id,
    required this.name,
    required this.pattern,
    required this.patternGroup,
    required this.modality,
    required this.equipment,
    required this.prescription,
    required this.techniqueChecks,
    required this.alternatives,
    required this.purpose,
    required this.startingInstruction,
  });

  factory Exercise.fromJson(Map<String, dynamic> j) {
    final load = j['load'];
    return Exercise(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '未命名动作',
      pattern: j['pattern'] as String? ?? '',
      patternGroup: j['pattern_group'] as String? ?? '',
      modality: j['modality'] as String? ?? '',
      equipment: j['equipment'] as String? ?? '',
      prescription: Prescription.fromJson(
        Map<String, dynamic>.from((j['prescription'] as Map?) ?? const {}),
      ),
      techniqueChecks: _stringList(j['technique_checks']),
      alternatives: _stringList(j['alternatives']),
      purpose: j['purpose'] as String? ?? '',
      startingInstruction:
          (load is Map ? load['starting_instruction'] as String? : null) ?? '',
    );
  }
}

class MinimumVersions {
  final List<String> minutes30;
  final List<String> minutes20;
  final List<String> minutes10;
  final String note30;

  const MinimumVersions({
    required this.minutes30,
    required this.minutes20,
    required this.minutes10,
    this.note30 = '',
  });

  factory MinimumVersions.fromJson(Map<String, dynamic> j) => MinimumVersions(
        minutes30: _stringList(j['minutes_30']?['exercise_ids']),
        minutes20: _stringList(j['minutes_20']?['exercise_ids']),
        minutes10: _stringList(j['minutes_10']?['exercise_ids']),
        note30: j['minutes_30']?['note'] as String? ?? '',
      );
}

class TrainingDay {
  final String id;
  final String title;
  final String theme;
  final String duration;
  final String role;
  final List<Exercise> exercises;
  final MinimumVersions minimumVersions;

  const TrainingDay({
    required this.id,
    required this.title,
    required this.theme,
    required this.duration,
    required this.role,
    required this.exercises,
    required this.minimumVersions,
  });

  factory TrainingDay.fromJson(Map<String, dynamic> j) => TrainingDay(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '训练日',
        theme: j['theme'] as String? ?? '',
        duration: j['duration'] as String? ?? '',
        role: j['role'] as String? ?? '',
        exercises: ((j['exercises'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        minimumVersions: MinimumVersions.fromJson(
          Map<String, dynamic>.from((j['minimum_versions'] as Map?) ?? const {}),
        ),
      );
}

class WorkoutSession {
  final int? id;
  final int? planId;
  final String? dayId;
  final String dayTitle;
  final String version;
  final String status;
  final String performedOn;
  final int? durationMin;
  final String? note;

  const WorkoutSession({
    this.id,
    this.planId,
    this.dayId,
    required this.dayTitle,
    required this.version,
    required this.status,
    required this.performedOn,
    this.durationMin,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'plan_id': planId,
        'day_id': dayId,
        'day_title': dayTitle,
        'version': version,
        'status': status,
        'performed_on': performedOn,
        'duration_min': durationMin,
        'note': note,
        'created_at': DateTime.now().toIso8601String(),
      };

  static WorkoutSession fromMap(Map<String, dynamic> m) => WorkoutSession(
        id: m['id'] as int?,
        planId: m['plan_id'] as int?,
        dayId: m['day_id'] as String?,
        dayTitle: m['day_title'] as String? ?? '自由训练',
        version: m['version'] as String? ?? 'full',
        status: m['status'] as String? ?? 'in_progress',
        performedOn: m['performed_on'] as String? ?? '',
        durationMin: (m['duration_min'] as num?)?.toInt(),
        note: m['note'] as String?,
      );
}

class SetLog {
  final int? id;
  final int sessionId;
  final String? exerciseKey;
  final String exerciseName;
  final int setIndex;
  final double? weight;
  final int? reps;
  final double? rpe;
  final bool isWarmup;

  const SetLog({
    this.id,
    required this.sessionId,
    this.exerciseKey,
    required this.exerciseName,
    required this.setIndex,
    this.weight,
    this.reps,
    this.rpe,
    this.isWarmup = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'session_id': sessionId,
        'exercise_key': exerciseKey,
        'exercise_name': exerciseName,
        'set_index': setIndex,
        'weight': weight,
        'reps': reps,
        'rpe': rpe,
        'is_warmup': isWarmup ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      };

  static SetLog fromMap(Map<String, dynamic> m) => SetLog(
        id: m['id'] as int?,
        sessionId: (m['session_id'] as num?)?.toInt() ?? 0,
        exerciseKey: m['exercise_key'] as String?,
        exerciseName: m['exercise_name'] as String? ?? '',
        setIndex: (m['set_index'] as num?)?.toInt() ?? 1,
        weight: (m['weight'] as num?)?.toDouble(),
        reps: (m['reps'] as num?)?.toInt(),
        rpe: (m['rpe'] as num?)?.toDouble(),
        isWarmup: ((m['is_warmup'] as num?)?.toInt() ?? 0) == 1,
      );
}

class BodyMetric {
  final int? id;
  final String recordedOn;
  final double? weightKg;
  final double? bodyFatPct;
  final double? chestCm;
  final double? waistCm;
  final double? hipCm;
  final double? armCm;
  final double? thighCm;
  final String? note;

  const BodyMetric({
    this.id,
    required this.recordedOn,
    this.weightKg,
    this.bodyFatPct,
    this.chestCm,
    this.waistCm,
    this.hipCm,
    this.armCm,
    this.thighCm,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'recorded_on': recordedOn,
        'weight_kg': weightKg,
        'body_fat_pct': bodyFatPct,
        'chest_cm': chestCm,
        'waist_cm': waistCm,
        'hip_cm': hipCm,
        'arm_cm': armCm,
        'thigh_cm': thighCm,
        'note': note,
        'created_at': DateTime.now().toIso8601String(),
      };

  static BodyMetric fromMap(Map<String, dynamic> m) => BodyMetric(
        id: m['id'] as int?,
        recordedOn: m['recorded_on'] as String? ?? '',
        weightKg: (m['weight_kg'] as num?)?.toDouble(),
        bodyFatPct: (m['body_fat_pct'] as num?)?.toDouble(),
        chestCm: (m['chest_cm'] as num?)?.toDouble(),
        waistCm: (m['waist_cm'] as num?)?.toDouble(),
        hipCm: (m['hip_cm'] as num?)?.toDouble(),
        armCm: (m['arm_cm'] as num?)?.toDouble(),
        thighCm: (m['thigh_cm'] as num?)?.toDouble(),
        note: m['note'] as String?,
      );
}

class NutritionTarget {
  final int? id;
  final String dayType;
  final int? kcal;
  final int? proteinG;
  final int? carbG;
  final int? fatG;

  const NutritionTarget({
    this.id,
    required this.dayType,
    this.kcal,
    this.proteinG,
    this.carbG,
    this.fatG,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'day_type': dayType,
        'kcal': kcal,
        'protein_g': proteinG,
        'carb_g': carbG,
        'fat_g': fatG,
        'created_at': DateTime.now().toIso8601String(),
      };

  static NutritionTarget fromMap(Map<String, dynamic> m) => NutritionTarget(
        id: m['id'] as int?,
        dayType: m['day_type'] as String? ?? 'training',
        kcal: (m['kcal'] as num?)?.toInt(),
        proteinG: (m['protein_g'] as num?)?.toInt(),
        carbG: (m['carb_g'] as num?)?.toInt(),
        fatG: (m['fat_g'] as num?)?.toInt(),
      );
}

class Meal {
  final int? id;
  final String eatenOn;
  final String slot;
  final String? name;
  final int kcal;
  final int proteinG;
  final int carbG;
  final int fatG;

  const Meal({
    this.id,
    required this.eatenOn,
    required this.slot,
    this.name,
    this.kcal = 0,
    this.proteinG = 0,
    this.carbG = 0,
    this.fatG = 0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'eaten_on': eatenOn,
        'slot': slot,
        'name': name,
        'kcal': kcal,
        'protein_g': proteinG,
        'carb_g': carbG,
        'fat_g': fatG,
        'created_at': DateTime.now().toIso8601String(),
      };

  static Meal fromMap(Map<String, dynamic> m) => Meal(
        id: m['id'] as int?,
        eatenOn: m['eaten_on'] as String? ?? '',
        slot: m['slot'] as String? ?? 'breakfast',
        name: m['name'] as String?,
        kcal: (m['kcal'] as num?)?.toInt() ?? 0,
        proteinG: (m['protein_g'] as num?)?.toInt() ?? 0,
        carbG: (m['carb_g'] as num?)?.toInt() ?? 0,
        fatG: (m['fat_g'] as num?)?.toInt() ?? 0,
      );
}

class WeeklyReview {
  final int? id;
  final String weekStart;
  final double? completionPct;
  final double? avgRpe;
  final int? sleepQuality;
  final int? soreness;
  final String? note;

  const WeeklyReview({
    this.id,
    required this.weekStart,
    this.completionPct,
    this.avgRpe,
    this.sleepQuality,
    this.soreness,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'week_start': weekStart,
        'completion_pct': completionPct,
        'avg_rpe': avgRpe,
        'sleep_quality': sleepQuality,
        'soreness': soreness,
        'note': note,
        'created_at': DateTime.now().toIso8601String(),
      };

  static WeeklyReview fromMap(Map<String, dynamic> m) => WeeklyReview(
        id: m['id'] as int?,
        weekStart: m['week_start'] as String? ?? '',
        completionPct: (m['completion_pct'] as num?)?.toDouble(),
        avgRpe: (m['avg_rpe'] as num?)?.toDouble(),
        sleepQuality: (m['sleep_quality'] as num?)?.toInt(),
        soreness: (m['soreness'] as num?)?.toInt(),
        note: m['note'] as String?,
      );
}

/* ------------------------------------------------------------------ 工具 */

String _encodeJson(Map<String, dynamic> v) => jsonEncode(v);

Map<String, dynamic> _decodeJson(dynamic raw) {
  if (raw == null) return <String, dynamic>{};
  if (raw is Map) return Map<String, dynamic>.from(raw);
  try {
    final decoded = jsonDecode(raw as String);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return <String, dynamic>{};
}

List<String> _stringList(dynamic v) =>
    (v is List) ? v.map((e) => e.toString()).toList() : const [];
