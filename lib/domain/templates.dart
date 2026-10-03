import '../data/models.dart';
import 'catalog.dart';

/// 三套内置计划模板，产出结构与 plan-contract.json 一致。
/// 渐进规则与中断规则来自 Lzheng-fitness knowledge/03 与 04。

class PlanTemplate {
  final String id;
  final String name;
  final String subtitle;
  final String level;
  final String frequency;
  final int weeks;
  final int daysPerWeek;
  final List<WeeklySlot> schedule;
  final List<TrainingDay> days;

  const PlanTemplate({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.level,
    required this.frequency,
    required this.weeks,
    required this.daysPerWeek,
    required this.schedule,
    required this.days,
  });
}

MinimumVersions _minimums(String prefix, List<String> a, List<String> b, List<String> c) =>
    MinimumVersions(
      minutes30: a.map((k) => '$prefix-$k').toList(),
      minutes20: b.map((k) => '$prefix-$k').toList(),
      minutes10: c.map((k) => '$prefix-$k').toList(),
      note30: '每个动作做 2 组',
    );

final List<PlanTemplate> kTemplates = [
  PlanTemplate(
    id: 'p0-fullbody-2',
    name: 'P0 全身 × 2',
    subtitle: '先建立稳定出勤与可重复动作',
    level: '零基础 / 停训后重启',
    frequency: '每周 2 练',
    weeks: 4,
    daysPerWeek: 2,
    schedule: const [
      WeeklySlot(dayIndex: 1, label: '周一', dayId: 'day-a', theme: '全身 A'),
      WeeklySlot(dayIndex: 4, label: '周四', dayId: 'day-b', theme: '全身 B'),
    ],
    days: [
      TrainingDay(
        id: 'day-a',
        title: '全身 A',
        theme: '膝主导、水平推拉',
        duration: '45—55 分钟',
        role: '建立可重复动作和基础容量',
        exercises: [
          place('a', 'legpress'),
          place('a', 'chestpress'),
          place('a', 'row'),
          place('a', 'plank'),
        ],
        minimumVersions:
            _minimums('a', ['legpress', 'chestpress', 'row'], ['legpress', 'row'], ['legpress']),
      ),
      TrainingDay(
        id: 'day-b',
        title: '全身 B',
        theme: '髋铰链、垂直推拉',
        duration: '40—50 分钟',
        role: '学习髋铰链并建立垂直方向能力',
        exercises: [
          place('b', 'hiphinge'),
          place('b', 'pulldown'),
          place('b', 'overheadpress'),
          place('b', 'legext'),
        ],
        minimumVersions: _minimums(
            'b', ['hiphinge', 'pulldown', 'overheadpress'], ['hiphinge', 'pulldown'], ['hiphinge']),
      ),
    ],
  ),
  PlanTemplate(
    id: 'fullbody-3',
    name: '全身 × 3',
    subtitle: '每周三次全身暴露，逐步加重',
    level: '有 1—3 个月基础',
    frequency: '每周 3 练',
    weeks: 6,
    daysPerWeek: 3,
    schedule: const [
      WeeklySlot(dayIndex: 1, label: '周一', dayId: 'day-a', theme: '全身 A'),
      WeeklySlot(dayIndex: 3, label: '周三', dayId: 'day-b', theme: '全身 B'),
      WeeklySlot(dayIndex: 5, label: '周五', dayId: 'day-c', theme: '全身 C'),
    ],
    days: [
      TrainingDay(
        id: 'day-a',
        title: '全身 A',
        theme: '蹲主导 + 水平推拉',
        duration: '55—65 分钟',
        role: '建立下肢与推拉力量',
        exercises: [
          place('a', 'gobletsquat'),
          place('a', 'benchpress'),
          place('a', 'row'),
          place('a', 'lateralraise'),
        ],
        minimumVersions: _minimums('a', ['gobletsquat', 'benchpress', 'row'],
            ['gobletsquat', 'row'], ['gobletsquat']),
      ),
      TrainingDay(
        id: 'day-b',
        title: '全身 B',
        theme: '髋铰链 + 垂直推拉',
        duration: '55—65 分钟',
        role: '强化伸髋与背链',
        exercises: [
          place('b', 'hipthrust'),
          place('b', 'overheadpress'),
          place('b', 'pulldown'),
          place('b', 'plank'),
        ],
        minimumVersions: _minimums('b', ['hipthrust', 'overheadpress', 'pulldown'],
            ['hipthrust', 'pulldown'], ['hipthrust']),
      ),
      TrainingDay(
        id: 'day-c',
        title: '全身 C',
        theme: '混合强化 + 薄弱补充',
        duration: '50—60 分钟',
        role: '补足直接与手臂容量',
        exercises: [
          place('c', 'legpress'),
          place('c', 'chestpress'),
          place('c', 'rdl'),
          place('c', 'curl'),
          place('c', 'triceps'),
        ],
        minimumVersions: _minimums(
            'c', ['legpress', 'chestpress', 'rdl'], ['legpress', 'chestpress'], ['legpress']),
      ),
    ],
  ),
  PlanTemplate(
    id: 'ppl-3',
    name: '推拉腿 × 3',
    subtitle: '推、拉、腿各一次专项容量',
    level: '有 6 个月以上基础',
    frequency: '每周 3 练',
    weeks: 8,
    daysPerWeek: 3,
    schedule: const [
      WeeklySlot(dayIndex: 1, label: '周一', dayId: 'day-push', theme: '推日'),
      WeeklySlot(dayIndex: 3, label: '周三', dayId: 'day-pull', theme: '拉日'),
      WeeklySlot(dayIndex: 5, label: '周五', dayId: 'day-legs', theme: '腿日'),
    ],
    days: [
      TrainingDay(
        id: 'day-push',
        title: '推日',
        theme: '水平推、垂直推、手臂伸',
        duration: '60—70 分钟',
        role: '建立推类专项容量',
        exercises: [
          place('push', 'benchpress'),
          place('push', 'overheadpress'),
          place('push', 'chestpress'),
          place('push', 'lateralraise'),
          place('push', 'triceps'),
        ],
        minimumVersions: _minimums('push', ['benchpress', 'overheadpress', 'chestpress'],
            ['benchpress', 'overheadpress'], ['benchpress']),
      ),
      TrainingDay(
        id: 'day-pull',
        title: '拉日',
        theme: '垂直拉、水平拉、手臂屈',
        duration: '60—70 分钟',
        role: '建立拉类专项容量',
        exercises: [
          place('pull', 'pullup'),
          place('pull', 'row'),
          place('pull', 'pulldown'),
          place('pull', 'curl'),
          place('pull', 'plank'),
        ],
        minimumVersions:
            _minimums('pull', ['pullup', 'row', 'pulldown'], ['row', 'pulldown'], ['row']),
      ),
      TrainingDay(
        id: 'day-legs',
        title: '腿日',
        theme: '蹲、髋铰链、腘绳与股四头',
        duration: '65—75 分钟',
        role: '建立下肢专项容量',
        exercises: [
          place('legs', 'gobletsquat'),
          place('legs', 'hipthrust'),
          place('legs', 'rdl'),
          place('legs', 'legext'),
          place('legs', 'legcurl'),
        ],
        minimumVersions: _minimums(
            'legs', ['gobletsquat', 'hipthrust', 'rdl'], ['gobletsquat', 'rdl'], ['gobletsquat']),
      ),
    ],
  ),
];

/// 把模板打包成可入库的 plan_json
Map<String, dynamic> buildPlanJson(PlanTemplate t,
    {String? title, String? location, int? weeks}) {
  final now = DateTime.now();
  final today = _dateKey(now);
  return {
    'plan_meta': {
      'title': title ?? t.name,
      'subtitle': t.subtitle,
      'generated_at': today,
      'timezone': 'Asia/Shanghai',
      'subject_mode': 'personal',
      'phase_goal': '用 ${weeks ?? t.weeks} 周稳定推进',
      'goal_mode': 'general_fitness',
      'frequency': t.frequency,
      'weeks': weeks ?? t.weeks,
      'next_training_day_id': t.days.first.id,
    },
    'profile_snapshot': {
      'snapshot_id': 'template-${t.id}-$today',
      'generated_at': today,
      'readiness': 'conservative',
      'overall_stage': t.id.startsWith('p0') ? 'P0' : 'L1',
      'confirmed': <String>[],
      'inferred': ['模板起点默认保守，第一次训练先做重量校准'],
      'unknown': ['近 8 周实际训练量', '可用器械清单'],
    },
    'safety_status': {
      'status': 'caution',
      'limitations': ['模板生成的计划不能替代专业评估；有疼痛或不适先停止'],
      'stop_signals': ['胸痛、晕厥、异常气短', '疼痛明显或持续加重', '麻木、放射痛、头晕'],
    },
    'goals': {
      'primary': '按排期稳定完成',
      'secondary': ['保持动作质量标准'],
      'success_criteria': ['每周按排期完成不少于 ${t.daysPerWeek} 次'],
    },
    'equipment': {
      'location': location ?? '商业健身房',
      'available': <String>[],
      'unavailable': <String>[],
    },
    'weekly_schedule': t.schedule
        .map((s) => {
              'day_index': s.dayIndex,
              'label': s.label,
              'day_id': s.dayId,
              'theme': s.theme,
            })
        .toList(),
    'training_days': t.days
        .map((d) => {
              'id': d.id,
              'title': d.title,
              'theme': d.theme,
              'duration': d.duration,
              'role': d.role,
              'exercises': d.exercises.map(exerciseToJson).toList(),
              'minimum_versions': {
                'minutes_30': {
                  'exercise_ids': d.minimumVersions.minutes30,
                  'note': d.minimumVersions.note30,
                },
                'minutes_20': {
                  'exercise_ids': d.minimumVersions.minutes20,
                  'note': '每个动作做 2 组，不追重量',
                },
                'minutes_10': {
                  'exercise_ids': d.minimumVersions.minutes10,
                  'note': '热身后完成 2 组，保留余量',
                },
              },
            })
        .toList(),
    'movement_coverage': <dynamic>[],
    'progression_rules': [
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
    ],
    'minimum_versions': [
      {'name': '30 分钟', 'rule': '保留主项和关键推拉'},
      {'name': '20 分钟', 'rule': '保留两个动作，每个两组'},
      {'name': '10 分钟', 'rule': '只完成热身与一个主要动作'},
    ],
    'short_interruption_rules': {
      'miss_one': '不补课，按原顺序继续',
      'miss_two': '下一次使用 30 分钟版',
      'route_to_return_skill': '停训达到 7 天或连续漏练 3 次时，先做一次状态复核再继续',
    },
    'review_checkpoints': [
      {'timing': '第 2 周末', 'collect': '完成率、RPE 偏差、动作稳定性', 'decision': '维持、微调或降级'},
      {'timing': '计划结束周', 'collect': '完成率、恢复、动作通过标准', 'decision': '决定是否进入下一阶段'},
    ],
    'knowledge_sources': <dynamic>[],
    'assumptions': ['由内置模板生成，第一个训练周用于重量校准'],
  };
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/* ------------------------------------------------------------ 版本 */

class DayVersion {
  final String key;
  final String label;
  const DayVersion(this.key, this.label);
}

const kDayVersions = [
  DayVersion('full', '完整版'),
  DayVersion('minutes_30', '30 分钟版'),
  DayVersion('minutes_20', '20 分钟版'),
  DayVersion('minutes_10', '10 分钟版'),
];

/// 按版本取当天要做的动作
List<Exercise> resolveDayExercises(TrainingDay day, String versionKey) {
  if (versionKey == 'full') return day.exercises;
  final ids = switch (versionKey) {
    'minutes_30' => day.minimumVersions.minutes30,
    'minutes_20' => day.minimumVersions.minutes20,
    'minutes_10' => day.minimumVersions.minutes10,
    _ => const <String>[],
  };
  if (ids.isEmpty) return day.exercises;
  return day.exercises.where((e) => ids.contains(e.id)).toList();
}
