import 'dart:convert';

import '../data/models.dart';
import 'catalog.dart';

/// 计划相关的一切：系统提示词、用户提示词、把模型输出修成能入库的结构。
/// 安全边界来自 Lzheng-fitness knowledge/01，动作选择顺序来自 references/exercise-selection.md。

class PlanSpec {
  PlanSpec({
    required this.daysPerWeek,
    required this.level,
    required this.goal,
    required this.minutes,
    required this.weeks,
    required this.equipment,
    this.limitations = '',
    this.note = '',
  });

  final int daysPerWeek;
  final String level; // 零基础 / 初级 / 中级
  final String goal; // 增肌 / 力量 / 减脂 / 体能
  final int minutes;
  final int weeks;
  final String equipment; // 全套器械 / 哑铃 / 自重
  final String limitations;
  final String note;

  String repRange() => switch (goal) {
        '力量' => '5—8 次，RPE 7—8，间歇 120—180 秒',
        '减脂' => '10—15 次，RPE 6—7，间歇 45—75 秒',
        '体能' => '10—15 次，RPE 6—7，间歇 60—90 秒',
        _ => '8—12 次，RPE 6—7，间歇 90 秒',
      };
}

String exerciseLibrary() => kCatalog
    .map((c) => '${c.key} | ${c.name} | ${c.pattern} | ${c.equipment} | ${c.repsMin}-${c.repsMax}')
    .join('\n');

const String systemPrompt = '''
你是力量训练计划生成器。对用户负责，保守优先。只输出一个 JSON 对象，不要解释，不要 Markdown 围栏，不要尾注。

【安全边界】
- 你面向健康成年人安排一般体能训练，不是医疗建议，不做诊断。
- 必须停止并就医的信号：胸痛、晕厥、异常气短、尖锐或放射痛、疼痛持续加重。把它写进 safety_status.stop_signals。
- 用户报告伤病时，选低风险替代动作并降低强度，绝不安排会诱发疼痛的动作。
- 常规硬拉只在同时满足三点时才安排：无腰痛史、能完成标准髋铰链、有足够的负重条件。否则用罗马尼亚硬拉或臀桥替代。

【编排规则】
- 每个训练日先排主项复合动作，再排辅助动作，最后排孤立与核心。
- 每个训练日安排 4—6 个动作。
- 同一周内推、拉、蹲、髋铰链都要覆盖到。
- 器械不满足时优先找同动作模式的替代，不要硬上做不了的动作。
- 第一次执行时重量未校准，所有 prescription 都要落在这个受众能安全起步的区间。

【动作 id 规则】
- 每个训练日有一个 day_id（如 day-a），训练日里的动作 id 必须是「day_id 去掉 day- 前缀再接 -key」的形式，
  例如 day-a 里的 chestpress 动作 id 是 a-chestpress，day-b 里就是 b-chestpress。

【输出结构】严格按这个 JSON，字段不要少：
{
  "plan_meta": {"subtitle": "一句话说明这个计划在做什么", "frequency": "每周 3 练"},
  "profile_snapshot": {"readiness": "conservative", "overall_stage": "P0", "confirmed": [], "inferred": []},
  "safety_status": {"status": "caution", "limitations": [], "stop_signals": []},
  "goals": {"primary": "", "secondary": [], "success_criteria": []},
  "weekly_schedule": [{"day_index": 1, "label": "周一", "day_id": "day-a", "theme": "推"}],
  "training_days": [
    {
      "id": "day-a",
      "title": "推日",
      "theme": "水平推、肩推、伸肘",
      "duration": "60 分钟",
      "role": "建立推类专项容量",
      "exercises": [
        {
          "id": "a-chestpress",
          "name": "哑铃卧推",
          "pattern": "水平推",
          "pattern_group": "推",
          "modality": "哑铃",
          "equipment": "哑铃",
          "purpose": "一句话说明为什么放这个动作",
          "prescription": {"set_count": 3, "reps_min": 8, "reps_max": 12, "reps": "8—12", "intensity": "RPE 6—7", "rest_seconds": 90, "rest": "90 秒"},
          "alternatives": ["替代动作名"],
          "technique_checks": ["一条动作质量要点"]
        }
      ],
      "minimum_versions": {
        "minutes_30": {"exercise_ids": ["a-chestpress", "a-row"], "note": "每个动作做 2 组"},
        "minutes_20": {"exercise_ids": ["a-chestpress", "a-row"], "note": "每个动作做 2 组"},
        "minutes_10": {"exercise_ids": ["a-chestpress"], "note": "热身后完成 2 组"}
      }
    }
  ]
}
day_index 的口径：1=周一，2=周二，一直到 7=周日。
''';

String buildUserPrompt(PlanSpec spec) {
  final buf = StringBuffer()
    ..writeln('请给我一份计划：')
    ..writeln('- 每周训练次数：${spec.daysPerWeek} 次')
    ..writeln('- 训练水平：${spec.level}')
    ..writeln('- 主要目标：${spec.goal}')
    ..writeln('- 单次可用时长：${spec.minutes} 分钟')
    ..writeln('- 计划周期：${spec.weeks} 周')
    ..writeln('- 可用器械：${spec.equipment}')
    ..writeln('- 处方基线：${spec.repRange()}');
  if (spec.limitations.trim().isNotEmpty) {
    buf.writeln('- 伤病与限制：${spec.limitations.trim()}（必须规避）');
  }
  if (spec.note.trim().isNotEmpty) {
    buf.writeln('- 补充说明：${spec.note.trim()}');
  }
  buf
    ..writeln()
    ..writeln('下面是可选动作库，每行是「key | 名称 | 动作模式 | 器械 | 次数区间」：')
    ..writeln(exerciseLibrary());
  return buf.toString();
}

/// 把模型输出修成 App 能直接消费的结构：缺字段补齐，坏结构兜底。
Map<String, dynamic> normalizePlan(
  Map<String, dynamic> raw, {
  required PlanSpec spec,
  String? title,
}) {
  final plan = Map<String, dynamic>.from(raw);

  final rawDays = plan['training_days'];
  final days = <Map<String, dynamic>>[];
  if (rawDays is List) {
    for (var i = 0; i < rawDays.length; i++) {
      final d = rawDays[i];
      if (d is! Map) continue;
      final day = Map<String, dynamic>.from(d);
      final dayId = (day['id'] as String?)?.trim() ?? 'day-${_letter(i)}';

      final rawExs = day['exercises'];
      final exs = <Map<String, dynamic>>[];
      if (rawExs is List) {
        for (var j = 0; j < rawExs.length; j++) {
          final e = rawExs[j];
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final pre = Map<String, dynamic>.from((m['prescription'] as Map?) ?? const {});

          final repsMin = (pre['reps_min'] as num?)?.toInt() ??
              int.tryParse('${pre['reps']}'.split(RegExp(r'[—\-–~]')).first.trim()) ??
              8;
          final repsMax = (pre['reps_max'] as num?)?.toInt() ?? repsMin + 4;
          final sets = (pre['set_count'] as num?)?.toInt() ??
              int.tryParse('${pre['sets']}') ??
              3;
          final rest = (pre['rest_seconds'] as num?)?.toInt() ?? 90;

          pre['set_count'] = sets.clamp(1, 10);
          pre['reps_min'] = repsMin.clamp(1, 60);
          pre['reps_max'] = repsMax < repsMin ? repsMin : repsMax.clamp(1, 60);
          pre['reps'] = (pre['reps'] as String?) ?? '${pre['reps_min']}—${pre['reps_max']}';
          pre['intensity'] = (pre['intensity'] as String?) ?? 'RPE 6—7';
          pre['rest_seconds'] = rest;
          pre['rest'] = (pre['rest'] as String?) ?? '$rest 秒';
          pre['sets'] = '${pre['set_count']}';

          final rawId = (m['id'] as String?)?.trim();
          m['id'] = (rawId != null && rawId.isNotEmpty)
              ? rawId
              : '${dayId.replaceFirst('day-', '')}-ex${j + 1}';
          m['name'] = (m['name'] as String?) ?? '动作 ${j + 1}';
          m['prescription'] = pre;
          m['technique_checks'] = _list(m['technique_checks']);
          m['alternatives'] = _list(m['alternatives']);
          m['purpose'] = (m['purpose'] as String?) ?? '';
          m['load'] = (m['load'] is Map)
              ? m['load']
              : {
                  'status': 'calibration_required',
                  'starting_instruction': kCalibrationInstruction,
                };
          exs.add(m);
        }
      }
      if (exs.isEmpty) continue;

      final ids = exs.map((e) => '${e['id']}').take(3).toList();
      final mv = (day['minimum_versions'] is Map)
          ? Map<String, dynamic>.from(day['minimum_versions'] as Map)
          : <String, dynamic>{};

      final rawTitle = (day['title'] as String?)?.trim();
      final rawDuration = (day['duration'] as String?)?.trim();
      day['id'] = dayId;
      day['title'] = (rawTitle != null && rawTitle.isNotEmpty) ? rawTitle : '训练日 ${i + 1}';
      day['theme'] = day['theme'] as String? ?? '';
      day['duration'] =
          (rawDuration != null && rawDuration.isNotEmpty) ? rawDuration : '${spec.minutes} 分钟';
      day['role'] = day['role'] as String? ?? '';
      day['exercises'] = exs;
      day['minimum_versions'] = {
        'minutes_30': {
          'exercise_ids': _idsFrom(mv['minutes_30'], ids),
          'note': '每个动作做 2 组，不追重量',
        },
        'minutes_20': {
          'exercise_ids': _idsFrom(mv['minutes_20'], ids.take(2).toList()),
          'note': '每个动作做 2 组',
        },
        'minutes_10': {
          'exercise_ids': _idsFrom(mv['minutes_10'], ids.take(1).toList()),
          'note': '热身后完成 2 组，保留余量',
        },
      };
      days.add(day);
    }
  }
  if (days.isEmpty) {
    throw const FormatException('模型没有给出可用的训练日，换个说法再试试');
  }
  plan['training_days'] = days;

  final schedule = <Map<String, dynamic>>[];
  final rawSchedule = plan['weekly_schedule'];
  if (rawSchedule is List && rawSchedule.isNotEmpty) {
    for (var i = 0; i < rawSchedule.length; i++) {
      final s = rawSchedule[i];
      if (s is! Map) continue;
      final idx = ((s['day_index'] as num?)?.toInt() ?? (i + 1)).clamp(1, 7);
      final day = days[i < days.length ? i : 0];
      schedule.add({
        'day_index': idx,
        'label': (s['label'] as String?) ?? _weekdayLabel(idx),
        'day_id': day['id'],
        'theme': (s['theme'] as String?) ?? day['title'],
      });
    }
  } else {
    final pattern = _defaultSchedule(days.length);
    for (var i = 0; i < days.length; i++) {
      schedule.add({
        'day_index': pattern[i],
        'label': _weekdayLabel(pattern[i]),
        'day_id': days[i]['id'],
        'theme': days[i]['title'],
      });
    }
  }
  plan['weekly_schedule'] = schedule;

  final meta = Map<String, dynamic>.from((plan['plan_meta'] as Map?) ?? const {});
  meta['title'] = title ?? '${spec.goal}计划 · 每周 ${spec.daysPerWeek} 练';
  meta['subtitle'] = meta['subtitle'] ?? 'AI 生成，第一周用于重量校准';
  meta['frequency'] = meta['frequency'] ?? '每周 ${spec.daysPerWeek} 练';
  meta['weeks'] = spec.weeks;
  meta['generated_at'] =
      meta['generated_at'] ?? DateTime.now().toIso8601String().substring(0, 10);
  meta['next_training_day_id'] = days.first['id'];
  plan['plan_meta'] = meta;

  final safety = Map<String, dynamic>.from((plan['safety_status'] as Map?) ?? const {});
  safety['status'] = safety['status'] ?? 'caution';
  safety['limitations'] = _list(safety['limitations']).isEmpty
      ? const ['这份计划不能替代专业评估；有疼痛或不适先停止']
      : _list(safety['limitations']);
  safety['stop_signals'] = _list(safety['stop_signals']).isEmpty
      ? const ['胸痛、晕厥、异常气短', '疼痛明显或持续加重', '麻木、放射痛、头晕']
      : _list(safety['stop_signals']);
  plan['safety_status'] = safety;

  plan['profile_snapshot'] ??= {
    'readiness': 'conservative',
    'overall_stage': spec.level == '零基础' ? 'P0' : 'L1',
    'inferred': const ['第一周用于重量校准'],
  };
  plan['goals'] ??= {
    'primary': spec.goal,
    'secondary': <String>[],
    'success_criteria': <String>['每周按排期完成 ${spec.daysPerWeek} 次'],
  };
  plan['equipment'] ??= {
    'location': spec.equipment,
    'available': <String>[],
    'unavailable': <String>[],
  };
  plan['movement_coverage'] ??= <dynamic>[];
  plan['progression_rules'] ??= [
    {
      'scope': '所有动作',
      'when': '所有工作组达到次数上限且末组不超过 RPE 7',
      'action': '下次增加一个最小重量单位，或先增加 1 次重复',
    },
    {
      'scope': '所有动作',
      'when': '连续两次同重量掉次数，或同组次 RPE 上升约一级',
      'action': '维持或降低一次载荷，先查恢复与技术',
    },
  ];
  plan['minimum_versions'] ??= [
    {'name': '30 分钟', 'rule': '保留主项和关键推拉'},
    {'name': '20 分钟', 'rule': '保留两个动作，每个两组'},
    {'name': '10 分钟', 'rule': '只完成热身与一个主要动作'},
  ];
  plan['short_interruption_rules'] ??= {
    'miss_one': '不补课，按原顺序继续',
    'miss_two': '下一次使用 30 分钟版',
    'route_to_return_skill': '停训达到 7 天或连续漏练 3 次时，先做一次状态复核再继续',
  };
  plan['review_checkpoints'] ??= [
    {'timing': '第 2 周末', 'collect': '完成率、RPE 偏差、动作稳定性', 'decision': '维持、微调或降级'},
    {'timing': '计划结束周', 'collect': '完成率、恢复、动作通过标准', 'decision': '决定是否进入下一阶段'},
  ];
  plan['assumptions'] ??= ['由大模型生成并经本地结构校验，第一个训练周用于重量校准'];
  plan['knowledge_sources'] ??= <dynamic>[];

  // 自检：必须能被 App 解析成 TrainingDay，否则视为坏输出
  final probe = Plan.fromMap({
    'id': 0,
    'title': 'probe',
    'weeks': spec.weeks,
    'start_date': '',
    'status': 'active',
    'plan_json': jsonEncode({'training_days': plan['training_days']}),
    'created_at': DateTime.now().toIso8601String(),
  });
  if (probe.trainingDays.isEmpty) {
    throw const FormatException('模型输出缺动作');
  }
  return plan;
}

List<String> _idsFrom(dynamic node, List<String> fallback) {
  if (node is Map) {
    final v = node['exercise_ids'];
    if (v is List && v.isNotEmpty) return v.map((e) => '$e').toList();
  }
  if (node is List && node.isNotEmpty) return node.map((e) => '$e').toList();
  return fallback;
}

List<String> _list(dynamic v) =>
    (v is List) ? v.map((e) => e.toString()).toList() : const <String>[];

String _letter(int i) => String.fromCharCode(97 + i);

String _weekdayLabel(int i) =>
    const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][(i - 1).clamp(0, 6)];

List<int> _defaultSchedule(int count) {
  switch (count) {
    case 1:
      return const [1];
    case 2:
      return const [1, 4];
    case 3:
      return const [1, 3, 5];
    case 4:
      return const [1, 2, 4, 5];
    case 5:
      return const [1, 2, 3, 5, 6];
    default:
      return const [1, 2, 3, 4, 5, 6];
  }
}
