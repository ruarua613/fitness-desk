import '../data/models.dart';

/// 内置动作库。字段对齐 plan-contract 的 exercise 结构。
class CatalogEntry {
  final String key;
  final String name;
  final String pattern;
  final String patternGroup;
  final String modality;
  final String equipment;
  final int setCount;
  final int repsMin;
  final int repsMax;
  final String intensity;
  final String rest;
  final int restSeconds;
  final String purpose;
  final List<String> checks;
  final List<String> alternatives;

  const CatalogEntry({
    required this.key,
    required this.name,
    required this.pattern,
    required this.patternGroup,
    required this.modality,
    required this.equipment,
    required this.setCount,
    required this.repsMin,
    required this.repsMax,
    required this.intensity,
    required this.rest,
    required this.restSeconds,
    required this.purpose,
    required this.checks,
    required this.alternatives,
  });
}

const List<CatalogEntry> kCatalog = [
  CatalogEntry(key: 'legpress', name: '腿举', pattern: '膝主导', patternGroup: '蹲', modality: '固定器械', equipment: '腿举机', setCount: 3, repsMin: 8, repsMax: 12, intensity: 'RPE 6—7', rest: '90—120 秒', restSeconds: 100, purpose: '建立下肢基础训练量', checks: ['全脚掌踩稳', '膝盖跟随脚尖方向'], alternatives: ['哈克深蹲', '箱式杯式深蹲']),
  CatalogEntry(key: 'gobletsquat', name: '高脚杯深蹲', pattern: '膝主导', patternGroup: '蹲', modality: '哑铃', equipment: '哑铃', setCount: 3, repsMin: 8, repsMax: 12, intensity: 'RPE 6—7', rest: '90—120 秒', restSeconds: 100, purpose: '建立蹲的基础容量', checks: ['躯干保持直立', '下蹲到大腿接近水平'], alternatives: ['箱式深蹲', '腿举']),
  CatalogEntry(key: 'rdl', name: '罗马尼亚硬拉', pattern: '髋主导', patternGroup: '髋铰链', modality: '杠铃', equipment: '杠铃', setCount: 3, repsMin: 8, repsMax: 10, intensity: 'RPE 6—7', rest: '120 秒', restSeconds: 120, purpose: '强化髋铰链与腘绳肌', checks: ['髋向后推', '腰背始终不塌'], alternatives: ['臀推', '垫高硬拉']),
  CatalogEntry(key: 'hiphinge', name: '绳索髋铰链', pattern: '髋主导', patternGroup: '髋铰链', modality: '绳索', equipment: '绳索机', setCount: 3, repsMin: 10, repsMax: 12, intensity: 'RPE 5—6', rest: '75—90 秒', restSeconds: 85, purpose: '建立无痛髋铰链', checks: ['髋向后移', '躯干保持稳定'], alternatives: ['垫高壶铃硬拉', '臀推']),
  CatalogEntry(key: 'chestpress', name: '坐姿推胸', pattern: '水平推', patternGroup: '推', modality: '固定器械', equipment: '推胸机', setCount: 3, repsMin: 8, repsMax: 12, intensity: 'RPE 6—7', rest: '75—90 秒', restSeconds: 85, purpose: '建立推的基础容量', checks: ['肩胛稳定', '手腕保持中立'], alternatives: ['上斜俯卧撑', '哑铃卧推']),
  CatalogEntry(key: 'benchpress', name: '杠铃卧推', pattern: '水平推', patternGroup: '推', modality: '杠铃', equipment: '卧推架', setCount: 4, repsMin: 5, repsMax: 8, intensity: 'RPE 7—8', rest: '150 秒', restSeconds: 150, purpose: '提升水平推的最大力量', checks: ['肩胛后收下沉', '杠铃落至胸骨中段'], alternatives: ['哑铃卧推', '坐姿推胸']),
  CatalogEntry(key: 'row', name: '坐姿划船', pattern: '水平拉', patternGroup: '拉', modality: '固定器械', equipment: '划船机', setCount: 3, repsMin: 10, repsMax: 12, intensity: 'RPE 6—7', rest: '75—90 秒', restSeconds: 85, purpose: '建立背部基础训练量', checks: ['不耸肩', '不借力后仰'], alternatives: ['胸托哑铃划船', '单臂哑铃划船']),
  CatalogEntry(key: 'pulldown', name: '高位下拉', pattern: '垂直拉', patternGroup: '拉', modality: '固定器械', equipment: '高位下拉机', setCount: 3, repsMin: 8, repsMax: 12, intensity: 'RPE 6—7', rest: '75—90 秒', restSeconds: 85, purpose: '建立垂直拉基础能力', checks: ['不甩动', '肩胛自然上回旋'], alternatives: ['弹力带下拉', '辅助引体']),
  CatalogEntry(key: 'overheadpress', name: '坐姿肩推', pattern: '垂直推', patternGroup: '推', modality: '哑铃', equipment: '哑铃凳', setCount: 3, repsMin: 8, repsMax: 10, intensity: 'RPE 6—7', rest: '90—120 秒', restSeconds: 100, purpose: '建立垂直推能力', checks: ['肋骨下沉不要挺腰', '手腕在肘正上方'], alternatives: ['器械肩推', '站姿单臂推举']),
  CatalogEntry(key: 'pullup', name: '引体向上', pattern: '垂直拉', patternGroup: '拉', modality: '自重', equipment: '单杠', setCount: 4, repsMin: 5, repsMax: 8, intensity: 'RPE 7—8', rest: '150 秒', restSeconds: 150, purpose: '自重垂直拉力量', checks: ['起始肩胛下沉', '不摆浪'], alternatives: ['高位下拉', '弹力带辅助引体']),
  CatalogEntry(key: 'legcurl', name: '腿弯举', pattern: '膝屈', patternGroup: '腘绳肌', modality: '固定器械', equipment: '腿弯举机', setCount: 3, repsMin: 10, repsMax: 12, intensity: 'RPE 6—7', rest: '75 秒', restSeconds: 75, purpose: '补充腘绳肌直接训练', checks: ['髋部不抬起', '回落有控制'], alternatives: ['北欧挺', '罗马尼亚硬拉']),
  CatalogEntry(key: 'legext', name: '坐姿腿屈伸', pattern: '膝伸', patternGroup: '股四头', modality: '固定器械', equipment: '腿屈伸机', setCount: 3, repsMin: 10, repsMax: 12, intensity: 'RPE 6—7', rest: '75 秒', restSeconds: 75, purpose: '补充股四头直接刺激', checks: ['膝盖对齐转轴', '顶点不停顿代偿'], alternatives: ['腿举', '保加利亚分腿蹲']),
  CatalogEntry(key: 'lateralraise', name: '侧平举', pattern: '肩外展', patternGroup: '肩', modality: '哑铃', equipment: '哑铃', setCount: 3, repsMin: 12, repsMax: 15, intensity: 'RPE 6—7', rest: '60 秒', restSeconds: 60, purpose: '补充肩中束', checks: ['肘略高于腕', '不耸肩'], alternatives: ['绳索侧平举', '器械侧平举']),
  CatalogEntry(key: 'curl', name: '哑铃弯举', pattern: '肘屈', patternGroup: '手臂', modality: '哑铃', equipment: '哑铃', setCount: 3, repsMin: 10, repsMax: 12, intensity: 'RPE 6—7', rest: '60 秒', restSeconds: 60, purpose: '补充屈肘肌群', checks: ['大臂固定不摆动', '回落有控制'], alternatives: ['绳索弯举', '锤式弯举']),
  CatalogEntry(key: 'triceps', name: '绳索下压', pattern: '肘伸', patternGroup: '手臂', modality: '绳索', equipment: '绳索机', setCount: 3, repsMin: 10, repsMax: 12, intensity: 'RPE 6—7', rest: '60 秒', restSeconds: 60, purpose: '补充伸肘肌群', checks: ['大臂夹紧体侧', '腕不甩'], alternatives: ['仰卧臂屈伸', '窄距俯卧撑']),
  CatalogEntry(key: 'plank', name: '平板支撑', pattern: '核心抗伸展', patternGroup: '核心', modality: '自重', equipment: '瑜伽垫', setCount: 3, repsMin: 3, repsMax: 3, intensity: '每次 30—45 秒', rest: '60 秒', restSeconds: 60, purpose: '建立躯干抗伸展能力', checks: ['骨盆后倾收腹', '不塌腰'], alternatives: ['死虫式', '鸟狗式']),
  CatalogEntry(key: 'hipthrust', name: '臀推', pattern: '髋主导', patternGroup: '髋铰链', modality: '杠铃', equipment: '卧推凳', setCount: 4, repsMin: 8, repsMax: 10, intensity: 'RPE 7—8', rest: '120 秒', restSeconds: 120, purpose: '强化伸髋峰值力量', checks: ['下巴微收', '顶点骨盆不前倾'], alternatives: ['罗马尼亚硬拉', '坐姿髋外展']),
];

final Map<String, CatalogEntry> kCatalogMap = {
  for (final e in kCatalog) e.key: e,
};

const String kCalibrationInstruction =
    '先用明显偏轻的重量完成 10 次试组，动作稳定后再逐步加重。';

/// 把动作库条目放进某个训练日
Exercise place(String prefix, String key) {
  final c = kCatalogMap[key];
  if (c == null) throw ArgumentError('未知动作: $key');
  return Exercise(
    id: '$prefix-$key',
    name: c.name,
    pattern: c.pattern,
    patternGroup: c.patternGroup,
    modality: c.modality,
    equipment: c.equipment,
    prescription: Prescription(
      setCount: c.setCount,
      reps: '${c.repsMin}—${c.repsMax}',
      repsMin: c.repsMin,
      repsMax: c.repsMax,
      intensity: c.intensity,
      rest: c.rest,
      restSeconds: c.restSeconds,
    ),
    techniqueChecks: c.checks,
    alternatives: c.alternatives,
    purpose: c.purpose,
    startingInstruction: kCalibrationInstruction,
  );
}

Map<String, dynamic> exerciseToJson(Exercise e) => {
      'id': e.id,
      'name': e.name,
      'pattern': e.pattern,
      'pattern_group': e.patternGroup,
      'modality': e.modality,
      'equipment': e.equipment,
      'prescription': {
        'sets': '${e.prescription.setCount}',
        'set_count': e.prescription.setCount,
        'reps': e.prescription.reps,
        'reps_min': e.prescription.repsMin,
        'reps_max': e.prescription.repsMax,
        'intensity': e.prescription.intensity,
        'rest': e.prescription.rest,
        'rest_seconds': e.prescription.restSeconds,
      },
      'muscle_contributions': const <Map<String, dynamic>>[],
      'load': {
        'status': 'calibration_required',
        'starting_instruction': e.startingInstruction,
      },
      'purpose': e.purpose,
      'priority': 'key',
      'alternatives': e.alternatives,
      'technique_checks': e.techniqueChecks,
    };
