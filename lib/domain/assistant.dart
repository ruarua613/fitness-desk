import 'dart:convert';

import '../data/repository.dart';
import '../data/settings.dart';
import 'catalog.dart';
import 'chat_message.dart';
import 'plan_prompt.dart';

/// AI 助手的大脑。
/// 两件事：
///   1. 把用户的身体数据、训练记录、当前计划和饮食情况摘成一段人话，塞进系统提示词；
///   2. 约定两种「可执行输出」——训练计划（plan 块）和饮食方案（diet 块），
///      识别出来后由页面提供「一键保存」按钮，直接落进对应模块。

const List<LlmPreset> kLlmPresets = [
  LlmPreset(
    name: '豆包（火山方舟）',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    modelHint: '填推理接入点 ID，形如 ep-2025xxxx-xxxxx',
    keyHint: '火山方舟控制台 → API Key 管理',
  ),
  LlmPreset(
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    modelHint: 'deepseek-chat 或 deepseek-reasoner',
    keyHint: 'platform.deepseek.com → API Keys',
  ),
  LlmPreset(
    name: '智谱 GLM',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    modelHint: 'glm-4-flash 或 glm-4-plus',
    keyHint: 'open.bigmodel.cn → API Keys',
  ),
  LlmPreset(
    name: '月之暗面 Kimi',
    baseUrl: 'https://api.moonshot.cn/v1',
    modelHint: 'moonshot-v1-8k',
    keyHint: 'platform.moonshot.cn → API Key',
  ),
  LlmPreset(
    name: '通义千问（兼容模式）',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    modelHint: 'qwen-plus',
    keyHint: '阿里云百炼 → API Key',
  ),
  LlmPreset(
    name: '本地 Ollama',
    baseUrl: 'http://localhost:11434/v1',
    modelHint: 'qwen2.5:7b 之类本地模型',
    keyHint: '本地随便填，例如 ollama',
  ),
];

class LlmPreset {
  const LlmPreset({
    required this.name,
    required this.baseUrl,
    required this.modelHint,
    required this.keyHint,
  });

  final String name;
  final String baseUrl;
  final String modelHint;
  final String keyHint;
}

const String assistantPersona = '''
你是「训练台」里的私人健身助手，同时懂力量训练和营养。说话直接、具体、不啰嗦，中文回答。

【你能拿到的信息】
下面会给你用户档案与近期记录摘要。引用数据时要说清日期，不确定的就说不确定，不要编造用户的历史数据。

【什么时候输出结构化结果】
只有在用户明确要「计划 / 方案 / 给我排一下」这类意图时才输出代码块；普通聊天、答疑、调整建议就用自然语言。

1) 训练计划：用 plan 围栏包一个 JSON，结构：
```plan
{
  "plan_meta": {"subtitle": "一句话说明这个计划做什么", "frequency": "每周 3 练"},
  "weekly_schedule": [{"day_index": 1, "label": "周一", "day_id": "day-a", "theme": "推"}],
  "training_days": [
    {
      "id": "day-a", "title": "推日", "theme": "水平推、肩推、伸肘",
      "duration": "60 分钟", "role": "建立推类容量",
      "exercises": [
        {
          "id": "a-chestpress", "name": "坐姿推胸", "pattern": "水平推",
          "pattern_group": "推", "modality": "固定器械", "equipment": "坐姿推胸机",
          "purpose": "为什么放这个动作",
          "prescription": {"set_count": 3, "reps_min": 8, "reps_max": 12,
                           "reps": "8—12", "intensity": "RPE 6—7",
                           "rest_seconds": 90, "rest": "90 秒"},
          "alternatives": ["替代动作"], "technique_checks": ["一条质量要点"]
        }
      ],
      "minimum_versions": {
        "minutes_30": {"exercise_ids": ["a-chestpress"], "note": "每个动作 2 组"},
        "minutes_20": {"exercise_ids": ["a-chestpress"], "note": "每个动作 2 组"},
        "minutes_10": {"exercise_ids": ["a-chestpress"], "note": "热身后 2 组"}
      }
    }
  ]
}
```
动作 id 规则：day-a 里的 chestpress 写成 a-chestpress；day_index 1=周一，到 7=周日。
每个训练日 4—6 个动作：先主项复合，再辅助，最后孤立与核心；一周内推、拉、蹲、髋铰链都要覆盖。
优先用用户器械条件允许的动作；器械不够就换同动作模式的替代。

2) 饮食方案：用 diet 围栏包一个 JSON，结构：
```diet
{
  "nutrition_target": {"day_type": "training", "kcal": 2200, "protein_g": 160, "carb_g": 250, "fat_g": 65},
  "meals": [
    {"slot": "breakfast", "name": "燕麦鸡蛋", "kcal": 480, "protein_g": 30, "carb_g": 55, "fat_g": 15}
  ],
  "notes": ["一条执行提示"]
}
```
slot 只能是 breakfast / lunch / dinner / snack。可以给训练日和休息日两套目标，
写两个代码块或者在一个块的 nutrition_target 里给训练日、再在 notes 里说休息日怎么调。

【安全边界】
- 面向健康成年人做一般体能与饮食安排，不做医疗建议、不做诊断、不开补剂处方。
- 出现胸痛、晕厥、异常气短、尖锐或放射痛、疼痛持续加重，要停止并建议就医。
- 用户提到伤病、慢性病、孕期、服药、进食障碍时，先建议咨询医生或营养师，再给保守的一般性建议。
- 热量不要给到极端赤字；减脂期一般不建议长期低于基础代谢，女性更保守。
- 蛋白质按体重给范围，不要给出超出常规安全范围的极端数值。
''';

/// 把 DB 里的数据摘成给模型看的摘要。
Future<String> buildProfileSummary(FitnessRepository repo, Settings settings) async {
  final buf = StringBuffer();
  buf.writeln('## 用户档案');

  final metrics = await repo.listBodyMetrics();
  if (metrics.isNotEmpty) {
    final m = metrics.last;
    final parts = <String>[];
    if (m.weightKg != null) parts.add('体重 ${m.weightKg} kg');
    if (m.bodyFatPct != null) parts.add('体脂 ${m.bodyFatPct}%');
    if (m.waistCm != null) parts.add('腰围 ${m.waistCm} cm');
    if (m.armCm != null) parts.add('臂围 ${m.armCm} cm');
    if (m.thighCm != null) parts.add('大腿 ${m.thighCm} cm');
    buf.writeln('- 最近一次身体数据（${m.recordedOn}）：${parts.isEmpty ? '只记了备注' : parts.join(' / ')}');
    if (metrics.length > 1) {
      final first = metrics.first;
      if (first.weightKg != null && m.weightKg != null && first != m) {
        final d = m.weightKg! - first.weightKg!;
        buf.writeln('- 体重变化：${first.recordedOn} ${first.weightKg} kg → ${m.recordedOn} ${m.weightKg} kg'
            '（${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)} kg）');
      }
    }
    if (m.note != null && m.note!.isNotEmpty) buf.writeln('- 当日备注：${m.note}');
  } else {
    buf.writeln('- 还没有身体数据记录');
  }

  final activeId = settings.activePlanId;
  if (activeId > 0) {
    final plan = await repo.getPlan(activeId);
    if (plan != null) {
      buf.writeln('- 当前计划：《${plan.title}》 ${plan.frequency.isEmpty ? '' : plan.frequency}'
          '，共 ${plan.weeks} 周，${plan.trainingDays.length} 个训练日');
      final names = plan.trainingDays.map((d) => d.title).join(' / ');
      if (names.isNotEmpty) buf.writeln('  训练日：$names');
      final recent = plan.trainingDays.take(2).map((d) {
        final ex = d.exercises.map((e) => e.name).join('、');
        return '${d.title}（$ex）';
      }).join('；');
      buf.writeln('  动作构成：$recent');
    }
  } else {
    buf.writeln('- 当前没有激活的计划');
  }

  final sessions = await repo.listSessions(limit: 40);
  if (sessions.isEmpty) {
    buf.writeln('- 还没有训练记录');
  } else {
    buf.writeln('- 累计训练 ${sessions.length} 次，最近：');
    for (final s in sessions.take(4)) {
      final sets = await repo.listSets(s.id ?? 0);
      if (sets.isEmpty) continue;
      final names = <String>[];
      final seen = <String>{};
      var best = '';
      for (final set in sets) {
        if (seen.add(set.exerciseName)) names.add(set.exerciseName);
        if (set.weight != null && set.weight! > 0) {
          final w = '${set.exerciseName} ${set.weight}kg×${set.reps ?? 0}';
          if (best.isEmpty || w.length > best.length) best = w;
        }
      }
      buf.writeln('  ${s.performedOn}｜${s.dayTitle}｜${sets.length} 组'
          '${best.isEmpty ? '' : '｜最好一组 $best'}'
          '｜动作：${names.take(5).join('、')}');
    }
  }

  final targets = await repo.listNutritionTargets();
  if (targets.isNotEmpty) {
    for (final t in targets) {
      buf.writeln('- 营养目标（${t.dayType == 'training' ? '训练日' : '休息日'}）：'
          '${t.kcal ?? '—'} kcal，蛋白 ${t.proteinG ?? '—'} g，碳水 ${t.carbG ?? '—'} g，脂肪 ${t.fatG ?? '—'} g');
    }
  } else {
    buf.writeln('- 还没有设营养目标');
  }

  final todayKey = DateTime.now();
  final today =
      '${todayKey.year}-${'${todayKey.month}'.padLeft(2, '0')}-${'${todayKey.day}'.padLeft(2, '0')}';
  final meals = await repo.listMeals(today);
  if (meals.isEmpty) {
    buf.writeln('- 今天还没有记录饮食');
  } else {
    var kcal = 0;
    var p = 0;
    for (final m in meals) {
      kcal += m.kcal;
      p += m.proteinG;
    }
    buf.writeln('- 今日已摄入：$kcal kcal，蛋白 $p g，共 ${meals.length} 餐（${meals.map((m) => m.name ?? m.slot).join('、')}）');
  }

  buf.writeln('- 加重最小单位：${settings.incrementKg} kg');
  buf.writeln('- 可用动作库（key｜名称｜模式｜器械）：');
  buf.writeln(exerciseLibrary());
  return buf.toString();
}

class AssistantBlock {
  const AssistantBlock({required this.kind, required this.json});

  final String kind; // plan / diet
  final Map<String, dynamic> json;
}

/// 从助手回复里挖出可执行的 JSON 块。
List<AssistantBlock> extractBlocks(String text) {
  final out = <AssistantBlock>[];
  final re = RegExp(r'```(\w+)?\s*([\s\S]*?)```', dotAll: true);
  for (final m in re.allMatches(text)) {
    final lang = (m.group(1) ?? '').toLowerCase();
    final body = (m.group(2) ?? '').trim();
    if (body.isEmpty || !body.startsWith('{')) continue;
    Map<String, dynamic> obj;
    try {
      final decoded = jsonLikeParse(body);
      if (decoded is! Map) continue;
      obj = Map<String, dynamic>.from(decoded);
    } catch (_) {
      continue;
    }
    String kind;
    if (lang == 'plan' || lang == 'diet') {
      kind = lang;
    } else if (obj['training_days'] is List) {
      kind = 'plan';
    } else if (obj['meals'] is List || obj['nutrition_target'] is Map) {
      kind = 'diet';
    } else {
      continue;
    }
    if (out.any((e) => e.kind == kind)) continue; // 每种只保留第一个
    out.add(AssistantBlock(kind: kind, json: obj));
  }
  return out;
}

dynamic jsonLikeParse(String body) {
  try {
    return jsonDecode(body);
  } catch (_) {
    // 模型偶尔漏掉收尾的括号，试着补齐再解一次
    final trimmed = body.trim();
    final open = '{'.allMatches(trimmed).length;
    final close = '}'.allMatches(trimmed).length;
    if (open > close) {
      return jsonDecode('$trimmed${'}' * (open - close)}');
    }
    rethrow;
  }
}

/// 给助手输出用的开场白
List<ChatMsg> starterMessages() => [
      ChatMsg(
        role: 'assistant',
        content: '我是你的健身助手，能看到你的身体数据、训练记录和饮食情况。\n\n'
            '直接说就行，比如：\n'
            '• 我这周只能练三天，给我排个计划\n'
            '• 按我现在的体重给我一套减脂饮食\n'
            '• 深蹲膝盖不舒服，换什么动作\n'
            '• 我最近状态一般，要不要降重量\n\n'
            '要完整的计划或饮食方案时我会输出结构化结果，下面会出现「保存」按钮，'
            '存进去就能在「今日」直接开练、在「身体」里看到营养进度。',
      ),
    ];

/// 把助手输出的 plan 块整理成能入库的 plan_json
Map<String, dynamic> normalizeAssistantPlan(
  Map<String, dynamic> raw, {
  required Settings settings,
}) {
  final schedule = raw['weekly_schedule'];
  final days = raw['training_days'];
  final daysPerWeek = (schedule is List && schedule.isNotEmpty)
      ? schedule.length
      : (days is List ? days.length : 3);
  final spec = PlanSpec(
    daysPerWeek: daysPerWeek,
    level: '初级',
    goal: '增肌',
    minutes: 60,
    weeks: 4,
    equipment: '全套器械',
  );
  final plan = normalizePlan(raw, spec: spec);
  (plan['plan_meta'] as Map)['title'] =
      (raw['plan_meta'] is Map ? (raw['plan_meta']['title'] as String?) : null) ??
          plan['plan_meta']['title'];
  return plan;
}
