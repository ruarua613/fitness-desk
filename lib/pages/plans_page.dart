import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../domain/templates.dart';
import '../scope.dart';
import '../utils.dart';
import '../widgets.dart';
import 'workout_page.dart';

/// 计划列表
class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  bool _loading = true;
  List<Plan> _plans = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final list = await AppScope.of(context).repo.listPlans();
    if (!mounted) return;
    setState(() {
      _plans = list;
      _loading = false;
    });
  }

  Future<void> _open(Plan p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlanDetailPage(planId: p.id ?? 0)),
    );
    _load();
  }

  Future<void> _newPlan() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewPlanPage()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('计划')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newPlan,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建计划'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _plans.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 40),
                      EmptyState(
                        icon: Icons.folder_open_rounded,
                        title: '还没有计划',
                        subtitle: '用内置模板起一个，或者把 AI 生成的计划 JSON 粘进来。',
                      ),
                    ],
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        ..._plans.map((p) => AppCard(
                              onTap: () => _open(p),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.title,
                                          style: TextStyle(
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.w700,
                                            color: cs.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (p.id == AppScope.of(context).settings.activePlanId)
                                        const InfoChip('当前', icon: Icons.check_rounded),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    p.subtitle.isEmpty ? '自定义计划' : p.subtitle,
                                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      InfoChip('${p.weeks} 周', icon: Icons.date_range_rounded),
                                      if (p.frequency.isNotEmpty)
                                        InfoChip(p.frequency, icon: Icons.repeat_rounded),
                                      InfoChip('${p.trainingDays.length} 个训练日',
                                          icon: Icons.list_alt_rounded),
                                    ],
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
      ),
    );
  }
}

/* ------------------------------------------------------------ 详情 */

class PlanDetailPage extends StatefulWidget {
  final int planId;
  const PlanDetailPage({super.key, required this.planId});

  @override
  State<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<PlanDetailPage> {
  Plan? _plan;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final p = await AppScope.of(context).repo.getPlan(widget.planId);
    if (!mounted) return;
    setState(() {
      _plan = p;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(
        title: Text(plan?.title ?? '计划'),
        actions: [
          if (plan != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'activate') {
                  AppScope.of(context).settings.activePlanId = plan.id ?? 0;
                  showToast(context, '已设为当前计划');
                  setState(() {});
                } else if (v == 'delete') {
                  final ok = await askConfirm(context, '删除这个计划？', '训练记录会保留，但不再关联计划。');
                  if (ok) {
                    await AppScope.of(context).repo.deletePlan(plan.id!);
                    if (mounted) Navigator.of(context).pop();
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'activate', child: Text('设为当前计划')),
                PopupMenuItem(value: 'delete', child: Text('删除计划')),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : plan == null
                ? const EmptyState(icon: Icons.error_outline_rounded, title: '计划不存在')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    children: [
                      if ((plan.planJson['safety_status']?['status'] ?? '') == 'caution')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.health_and_safety_rounded, color: cs.error, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '模板生成的计划不能替代专业评估。出现胸痛、晕厥、异常气短，或疼痛明显并持续加重，立刻停止。',
                                    style: TextStyle(fontSize: 12.5, height: 1.5, color: cs.onSurface),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KVRow('副标题', plan.subtitle.isEmpty ? '—' : plan.subtitle),
                            KVRow('频率', plan.frequency.isEmpty ? '—' : plan.frequency),
                            KVRow('周期', '${plan.weeks} 周'),
                            KVRow('开始', plan.startDate),
                          ],
                        ),
                      ),
                      if (plan.weeklySchedule.isNotEmpty) ...[
                        const SectionTitle('周排期'),
                        AppCard(
                          child: Column(
                            children: plan.weeklySchedule
                                .map(
                                  (s) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 48,
                                          child: Text(
                                            weekdayLabel(s.dayIndex),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: cs.onSurface,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            s.theme.isEmpty ? s.label : s.theme,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            final day = plan.trainingDays
                                                .where((d) => d.id == s.dayId)
                                                .cast<TrainingDay?>()
                                                .firstWhere((d) => d != null,
                                                    orElse: () => null);
                                            if (day == null) return;
                                            await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => WorkoutPage(
                                                  planId: plan.id,
                                                  dayId: day.id,
                                                  dayTitle: day.title,
                                                  version: 'full',
                                                  exercises: day.exercises,
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text('开练'),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      const SectionTitle('训练日'),
                      ...plan.trainingDays.map(
                        (d) => AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${d.theme} · ${d.duration}',
                                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 8),
                              ...d.exercises.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.name,
                                          style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                                        ),
                                      ),
                                      Text(
                                        '${e.prescription.setCount}×${e.prescription.reps}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

/* ------------------------------------------------------------ 新建 */

class NewPlanPage extends StatefulWidget {
  const NewPlanPage({super.key});

  @override
  State<NewPlanPage> createState() => _NewPlanPageState();
}

class _NewPlanPageState extends State<NewPlanPage> {
  PlanTemplate _tpl = kTemplates.first;
  final TextEditingController _title = TextEditingController();
  final TextEditingController _weeks = TextEditingController(text: '4');
  final TextEditingController _location = TextEditingController(text: '商业健身房');
  final TextEditingController _json = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title.text = _tpl.name;
    _weeks.text = '${_tpl.weeks}';
  }

  @override
  void dispose() {
    _title.dispose();
    _weeks.dispose();
    _location.dispose();
    _json.dispose();
    super.dispose();
  }

  Future<void> _createFromTemplate() async {
    setState(() => _saving = true);
    try {
      final weeks = parseInt(_weeks.text) ?? _tpl.weeks;
      final title = _title.text.trim().isEmpty ? _tpl.name : _title.text.trim();
      final json = buildPlanJson(
        _tpl,
        title: title,
        location: _location.text.trim(),
        weeks: weeks,
      );
      final scope = AppScope.of(context);
      final created = await scope.repo.createPlan(
        Plan(
          title: title,
          weeks: weeks,
          startDate: todayKey(),
          status: 'active',
          planJson: json,
          createdAt: DateTime.now(),
        ),
      );
      scope.settings.activePlanId = created.id ?? 0;
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, '创建失败：$e');
    }
  }

  Future<void> _importJson() async {
    final text = _json.text.trim();
    if (text.isEmpty) {
      showToast(context, '先把计划 JSON 粘进来');
      return;
    }
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) throw const FormatException('顶层必须是对象');
      map = Map<String, dynamic>.from(decoded);
    } catch (e) {
      showToast(context, 'JSON 解析失败：$e');
      return;
    }
    if (map['training_days'] is! List) {
      showToast(context, '缺少 training_days 字段');
      return;
    }
    setState(() => _saving = true);
    try {
      final meta = Map<String, dynamic>.from((map['plan_meta'] as Map?) ?? const {});
      final title = (meta['title'] as String?) ?? '导入的计划';
      final weeks = (meta['weeks'] as num?)?.toInt() ?? 4;
      final scope = AppScope.of(context);
      final created = await scope.repo.createPlan(
        Plan(
          title: title,
          weeks: weeks,
          startDate: todayKey(),
          status: 'active',
          planJson: map,
          createdAt: DateTime.now(),
        ),
      );
      scope.settings.activePlanId = created.id ?? 0;
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, '导入失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('新建计划'),
          bottom: const TabBar(
            tabs: [Tab(text: '从模板'), Tab(text: '导入 JSON')],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  const SectionTitle('选一个起点'),
                  ...kTemplates.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        onTap: () => setState(() {
                          _tpl = t;
                          _title.text = t.name;
                          _weeks.text = '${t.weeks}';
                        }),
                        child: Row(
                          children: [
                            Icon(
                              _tpl.id == t.id
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: _tpl.id == t.id ? cs.primary : cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${t.subtitle} · 每周 ${t.daysPerWeek} 次 · ${t.level}',
                                    style:
                                        TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SectionTitle('计划信息'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          TextField(
                            controller: _title,
                            decoration: const InputDecoration(labelText: '计划名称'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _weeks,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '周数',
                              suffixText: '周',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _location,
                            decoration: const InputDecoration(labelText: '训练场地'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _saving ? null : _createFromTemplate,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('创建并设为当前'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '模板按 plan-contract 生成：第一周用于重量校准，之后按「次数上限 + RPE」规则推进。',
                    style: TextStyle(fontSize: 12, height: 1.6, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  Text(
                    '把 AI 按 plan-contract 生成的计划 JSON 粘进来。至少要包含 training_days。',
                    style: TextStyle(fontSize: 13, height: 1.6, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _json,
                        maxLines: 16,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          hintText: '{\n  "plan_meta": {...},\n  "training_days": [...]\n}',
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _importJson,
                    icon: const Icon(Icons.file_download_rounded),
                    label: const Text('导入并设为当前'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
