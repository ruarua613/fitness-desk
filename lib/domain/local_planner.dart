import '../data/models.dart';
import 'catalog.dart';
import 'templates.dart';
import 'plan_prompt.dart';

/// 离线兜底：没配大模型 Key 时，也能按「器械 + 目标 + 频率」排出一份结构完整的计划。
/// 规则来自 Lzheng-fitness knowledge/03 与 references/exercise-selection.md：
/// 先主项复合，再辅助，再孤立与核心；一周内推拉蹲髋铰链都覆盖到。
class LocalPlanner {
  static const _squat = ['legpress', 'gobletsquat'];
  static const _hinge = ['hipthrust', 'rdl', 'hiphinge'];
  static const _hPush = ['benchpress', 'chestpress'];
  static const _vPush = ['overheadpress'];
  static const _hPull = ['row'];
  static const _vPull = ['pulldown', 'pullup'];
  static const _quad = ['legext'];
  static const _ham = ['legcurl'];
  static const _shoulder = ['lateralraise'];
  static const _armFlex = ['curl'];
  static const _armExt = ['triceps'];
  static const _core = ['plank'];

  static const _presets = {
    2: [
      ['全身 A', '蹲、水平推拉、核心', [_squat, _hPush, _hPull, _core, _quad]],
      ['全身 B', '髋铰链、垂直推拉、手臂', [_hinge, _vPush, _vPull, _armExt, _core]],
    ],
    3: [
      ['推日', '水平推、垂直推、肩与伸肘', [_hPush, _vPush, _shoulder, _armExt, _core]],
      ['拉日', '垂直拉、水平拉、屈肘', [_vPull, _hPull, _armFlex, _core]],
      ['腿日', '蹲、髋铰链、腘绳与股四头', [_squat, _hinge, _quad, _ham, _core]],
    ],
    4: [
      ['上肢 A', '水平推、水平拉、手臂', [_hPush, _hPull, _armFlex, _armExt]],
      ['下肢 A', '蹲、股四头、腘绳', [_squat, _quad, _ham, _core]],
      ['上肢 B', '垂直推、垂直拉、肩', [_vPush, _vPull, _shoulder, _core]],
      ['下肢 B', '髋铰链、蹲辅助、核心', [_hinge, _squat, _core, _ham]],
    ],
  };

  static const _prefixes = ['a', 'b', 'c', 'd'];

  static Map<String, dynamic> build(PlanSpec spec) {
    final preset = _presets[spec.daysPerWeek] ?? _presets[3]!;
    final allowed = _allowance(spec.equipment);
    final maxExercises = spec.minutes <= 45 ? 4 : (spec.minutes >= 75 ? 6 : 5);

    final days = <TrainingDay>[];
    final schedule = <WeeklySlot>[];
    final pattern = _schedulePattern(preset.length);

    for (var i = 0; i < preset.length; i++) {
      final p = _prefixes[i];
      final picked = <String>[];
      for (final slot in preset[i][2] as List<List<String>>) {
        final key = slot.firstWhere(
          (k) => allowed.contains(k),
          orElse: () => '',
        );
        if (key.isNotEmpty && !picked.contains(key)) picked.add(key);
      }
      if (picked.length < maxExercises) {
        for (final k in allowed) {
          if (picked.length >= maxExercises) break;
          if (!picked.contains(k)) picked.add(k);
        }
      }
      final exercises = picked
          .take(maxExercises)
          .map((k) => _retune(place(p, k), k, spec))
          .toList();

      final titles = preset[i][0] as String;
      days.add(
        TrainingDay(
          id: 'day-$p',
          title: titles,
          theme: preset[i][1] as String,
          duration: '${spec.minutes} 分钟',
          role: titles.contains('腿') || titles.contains('下肢')
              ? '建立下肢容量'
              : (titles.contains('拉') ? '建立拉类容量' : '建立推类容量'),
          exercises: exercises,
          minimumVersions: MinimumVersions(
            minutes30: exercises.take(3).map((e) => e.id).toList(),
            minutes20: exercises.take(2).map((e) => e.id).toList(),
            minutes10: exercises.take(1).map((e) => e.id).toList(),
            note30: '每个动作做 2 组',
          ),
        ),
      );
      schedule.add(
        WeeklySlot(
          dayIndex: pattern[i],
          label: _weekdayLabel(pattern[i]),
          dayId: 'day-$p',
          theme: preset[i][1] as String,
        ),
      );
    }

    final name = '${spec.goal} · 每周 ${spec.daysPerWeek} 练';
    final tpl = PlanTemplate(
      id: 'local-${spec.daysPerWeek}${spec.goal.hashCode.abs() % 9973}',
      name: name,
      subtitle: '按${spec.equipment}条件离线编排，第一周用于重量校准',
      level: spec.level,
      frequency: '每周 ${spec.daysPerWeek} 练',
      weeks: spec.weeks,
      daysPerWeek: spec.daysPerWeek,
      schedule: schedule,
      days: days,
    );
    return buildPlanJson(
      tpl,
      title: name,
      location: spec.equipment,
      weeks: spec.weeks,
    );
  }

  static List<String> _allowance(String equipment) {
    final pool = <String>[];
    void take(Iterable<String> modalities) {
      for (final c in kCatalog) {
        if (modalities.contains(c.modality) && !pool.contains(c.key)) {
          pool.add(c.key);
        }
      }
    }

    switch (equipment) {
      case '仅自重':
        take(const ['自重']);
        if (pool.length < 3) take(const ['哑铃']);
        break;
      case '哑铃为主':
        take(const ['哑铃', '自重']);
        if (pool.length < 4) take(const ['固定器械', '绳索']);
        break;
      default:
        take(const ['固定器械', '杠铃', '哑铃', '绳索', '自重']);
    }
    if (pool.isEmpty) take(const ['固定器械', '杠铃', '哑铃', '绳索', '自重']);
    return pool;
  }

  static Exercise _retune(Exercise base, String key, PlanSpec spec) {
    final main = const ['legpress', 'gobletsquat', 'hipthrust', 'rdl', 'benchpress', 'chestpress'];
    final (min, max, intensity, rest) = switch (spec.goal) {
      '力量' => (5, 8, 'RPE 7—8', 150),
      '减脂' => (12, 15, 'RPE 6—7', 60),
      '体能' => (10, 15, 'RPE 6—7', 75),
      _ => (8, 12, 'RPE 6—7', 90),
    };
    final p = base.prescription;
    final isMain = main.contains(key);
    final isCore = key == 'plank';
    return Exercise(
      id: base.id,
      name: base.name,
      pattern: base.pattern,
      patternGroup: base.patternGroup,
      modality: base.modality,
      equipment: base.equipment,
      prescription: Prescription(
        setCount: isCore ? 3 : (isMain ? 4 : p.setCount),
        reps: isCore ? p.reps : '$min—$max',
        repsMin: isCore ? p.repsMin : min,
        repsMax: isCore ? p.repsMax : max,
        intensity: isCore ? p.intensity : intensity,
        rest: isCore ? p.rest : '$rest 秒',
        restSeconds: isCore ? p.restSeconds : rest,
      ),
      techniqueChecks: base.techniqueChecks,
      alternatives: base.alternatives,
      purpose: base.purpose,
      startingInstruction: base.startingInstruction,
    );
  }

  static List<int> _schedulePattern(int count) {
    switch (count) {
      case 1:
        return const [1];
      case 2:
        return const [1, 4];
      case 4:
        return const [1, 2, 4, 5];
      default:
        return const [1, 3, 5];
    }
  }

  static String _weekdayLabel(int i) =>
      const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][(i - 1).clamp(0, 6)];
}
