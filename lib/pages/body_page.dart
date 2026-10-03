import 'package:flutter/material.dart';

import '../data/models.dart';
import '../scope.dart';
import '../utils.dart';
import '../widgets.dart';

class BodyPage extends StatefulWidget {
  const BodyPage({super.key});

  @override
  State<BodyPage> createState() => _BodyPageState();
}

class _BodyPageState extends State<BodyPage> {
  bool _loading = true;
  List<BodyMetric> _metrics = [];
  List<NutritionTarget> _targets = [];
  List<Meal> _meals = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final repo = AppScope.of(context).repo;
    final results = await Future.wait([
      repo.listBodyMetrics(),
      repo.listNutritionTargets(),
      repo.listMeals(todayKey()),
    ]);
    if (!mounted) return;
    setState(() {
      _metrics = results[0] as List<BodyMetric>;
      _targets = results[1] as List<NutritionTarget>;
      _meals = results[2] as List<Meal>;
      _loading = false;
    });
  }

  /* ------------------------------------------------------------ 身体 */

  Future<void> _editMetric([BodyMetric? existing]) async {
    final isNew = existing == null;
    final c = {
      for (final k in ['weight', 'fat', 'chest', 'waist', 'hip', 'arm', 'thigh'])
        k: TextEditingController()
    };
    final note = TextEditingController();
    if (existing != null) {
      c['weight']!.text = existing.weightKg != null ? '${existing.weightKg}' : '';
      c['fat']!.text = existing.bodyFatPct != null ? '${existing.bodyFatPct}' : '';
      c['chest']!.text = existing.chestCm != null ? '${existing.chestCm}' : '';
      c['waist']!.text = existing.waistCm != null ? '${existing.waistCm}' : '';
      c['hip']!.text = existing.hipCm != null ? '${existing.hipCm}' : '';
      c['arm']!.text = existing.armCm != null ? '${existing.armCm}' : '';
      c['thigh']!.text = existing.thighCm != null ? '${existing.thighCm}' : '';
      note.text = existing.note ?? '';
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isNew ? '记录身体数据' : '编辑记录',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: NumberField(label: '体重', controller: c['weight']!, suffix: 'kg')),
                  const SizedBox(width: 10),
                  Expanded(child: NumberField(label: '体脂', controller: c['fat']!, suffix: '%')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: NumberField(label: '胸围', controller: c['chest']!, suffix: 'cm')),
                  const SizedBox(width: 10),
                  Expanded(child: NumberField(label: '腰围', controller: c['waist']!, suffix: 'cm')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: NumberField(label: '臀围', controller: c['hip']!, suffix: 'cm')),
                  const SizedBox(width: 10),
                  Expanded(child: NumberField(label: '臂围', controller: c['arm']!, suffix: 'cm')),
                ],
              ),
              const SizedBox(height: 10),
              NumberField(label: '大腿围', controller: c['thigh']!, suffix: 'cm'),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: '备注（可选）'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true) {
      for (final v in c.values) {
        v.dispose();
      }
      note.dispose();
      return;
    }

    final metric = BodyMetric(
      id: existing?.id,
      recordedOn: existing?.recordedOn ?? todayKey(),
      weightKg: parseDouble(c['weight']!.text),
      bodyFatPct: parseDouble(c['fat']!.text),
      chestCm: parseDouble(c['chest']!.text),
      waistCm: parseDouble(c['waist']!.text),
      hipCm: parseDouble(c['hip']!.text),
      armCm: parseDouble(c['arm']!.text),
      thighCm: parseDouble(c['thigh']!.text),
      note: note.text.trim().isEmpty ? null : note.text.trim(),
    );
    for (final v in c.values) {
      v.dispose();
    }
    note.dispose();

    await AppScope.of(context).repo.upsertBodyMetric(metric);
    _load();
  }

  Widget _bodyTab(ColorScheme cs) {
    final withWeight = _metrics.where((m) => m.weightKg != null).toList();
    final latest = withWeight.isNotEmpty ? withWeight.last : null;
    final first = withWeight.isNotEmpty ? withWeight.first : null;
    final delta = (latest != null && first != null && latest != first)
        ? latest.weightKg! - first.weightKg!
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Row(
          children: [
            StatTile(
              label: '当前体重',
              value: fmtWeight(latest?.weightKg),
              unit: 'kg',
              icon: Icons.monitor_weight_rounded,
            ),
            const SizedBox(width: 10),
            StatTile(
              label: '体脂',
              value: latest?.bodyFatPct != null ? fmtQty(latest!.bodyFatPct) : '—',
              unit: latest?.bodyFatPct != null ? '%' : '',
            ),
          ],
        ),
        if (withWeight.length > 1) ...[
          const SectionTitle('体重变化'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SparkLine(values: withWeight.map((m) => m.weightKg!).toList()),
                const SizedBox(height: 8),
                Text(
                  '${shortDate(first!.recordedOn)} → ${shortDate(latest!.recordedOn)}'
                  '${delta != null ? '，${delta >= 0 ? '+' : ''}${fmtQty(delta)} kg' : ''}',
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
        SectionTitle(
          '记录',
          trailing: TextButton.icon(
            onPressed: () => _editMetric(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('记一次'),
          ),
        ),
        if (_metrics.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: EmptyState(
              icon: Icons.straighten_rounded,
              title: '还没有身体数据',
              subtitle: '每次称重记一条，应用会画趋势线。',
            ),
          )
        else
          ..._metrics.reversed.map(
            (m) => AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friendlyDate(m.recordedOn),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (m.weightKg != null) '${fmtWeight(m.weightKg)} kg',
                            if (m.bodyFatPct != null) '体脂 ${fmtQty(m.bodyFatPct)}%',
                            if (m.waistCm != null) '腰 ${fmtQty(m.waistCm)}cm',
                          ].join(' · '),
                          style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                        ),
                        if (m.note != null && m.note!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            m.note!,
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        _editMetric(m);
                      } else if (v == 'delete' && m.id != null) {
                        await AppScope.of(context).repo.deleteBodyMetric(m.id!);
                        _load();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /* ------------------------------------------------------------ 营养 */

  NutritionTarget? _target(String dayType) {
    for (final t in _targets) {
      if (t.dayType == dayType) return t;
    }
    return null;
  }

  Future<void> _editTarget(String dayType) async {
    final existing = _target(dayType);
    final kcal = TextEditingController(text: existing?.kcal?.toString() ?? '');
    final p = TextEditingController(text: existing?.proteinG?.toString() ?? '');
    final c = TextEditingController(text: existing?.carbG?.toString() ?? '');
    final f = TextEditingController(text: existing?.fatG?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dayType == 'training' ? '训练日目标' : '休息日目标'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NumberField(label: '热量', controller: kcal, suffix: 'kcal'),
            const SizedBox(height: 10),
            NumberField(label: '蛋白质', controller: p, suffix: 'g'),
            const SizedBox(height: 10),
            NumberField(label: '碳水', controller: c, suffix: 'g'),
            const SizedBox(height: 10),
            NumberField(label: '脂肪', controller: f, suffix: 'g'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );

    if (ok != true) {
      for (final v in [kcal, p, c, f]) {
        v.dispose();
      }
      return;
    }
    final target = NutritionTarget(
      id: existing?.id,
      dayType: dayType,
      kcal: parseInt(kcal.text),
      proteinG: parseInt(p.text),
      carbG: parseInt(c.text),
      fatG: parseInt(f.text),
    );
    for (final v in [kcal, p, c, f]) {
      v.dispose();
    }
    await AppScope.of(context).repo.upsertNutritionTarget(target);
    _load();
  }

  Future<void> _addMeal() async {
    final name = TextEditingController();
    final kcal = TextEditingController();
    final p = TextEditingController();
    final c = TextEditingController();
    final f = TextEditingController();
    String slot = 'breakfast';

    const slots = [
      ('breakfast', '早餐'),
      ('lunch', '午餐'),
      ('dinner', '晚餐'),
      ('snack', '加餐'),
    ];

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '记一餐',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: slots
                      .map(
                        (s) => ChoiceChip(
                          label: Text(s.$2),
                          selected: slot == s.$1,
                          onSelected: (_) => setLocal(() => slot = s.$1),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(controller: name, decoration: const InputDecoration(labelText: '吃了什么')),
                const SizedBox(height: 10),
                NumberField(label: '热量', controller: kcal, suffix: 'kcal'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: NumberField(label: '蛋白', controller: p, suffix: 'g')),
                    const SizedBox(width: 10),
                    Expanded(child: NumberField(label: '碳水', controller: c, suffix: 'g')),
                    const SizedBox(width: 10),
                    Expanded(child: NumberField(label: '脂肪', controller: f, suffix: 'g')),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (ok != true) {
      for (final v in [name, kcal, p, c, f]) {
        v.dispose();
      }
      return;
    }
    final meal = Meal(
      eatenOn: todayKey(),
      slot: slot,
      name: name.text.trim().isEmpty ? null : name.text.trim(),
      kcal: parseInt(kcal.text) ?? 0,
      proteinG: parseInt(p.text) ?? 0,
      carbG: parseInt(c.text) ?? 0,
      fatG: parseInt(f.text) ?? 0,
    );
    for (final v in [name, kcal, p, c, f]) {
      v.dispose();
    }
    await AppScope.of(context).repo.addMeal(meal);
    _load();
  }

  Widget _nutritionTab(ColorScheme cs) {
    final training = _target('training');
    var kcal = 0;
    var p = 0;
    var c = 0;
    var f = 0;
    for (final m in _meals) {
      kcal += m.kcal;
      p += m.proteinG;
      c += m.carbG;
      f += m.fatG;
    }
    final targetKcal = training?.kcal ?? 0;
    final progress = targetKcal > 0 ? (kcal / targetKcal).clamp(0.0, 1.0) : 0.0;

    const slotLabel = {
      'breakfast': '早餐',
      'lunch': '午餐',
      'dinner': '晚餐',
      'snack': '加餐',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Row(
          children: [
            StatTile(label: '今日热量', value: '$kcal', unit: 'kcal', icon: Icons.local_fire_department_rounded),
            const SizedBox(width: 10),
            StatTile(label: '蛋白质', value: '$p', unit: 'g'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            StatTile(label: '碳水', value: '$c', unit: 'g'),
            const SizedBox(width: 10),
            StatTile(label: '脂肪', value: '$f', unit: 'g'),
          ],
        ),
        const SectionTitle('目标完成度'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.toDouble(),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                targetKcal > 0
                    ? '$kcal / $targetKcal kcal（${(progress * 100).round()}%）'
                    : '还没有设热量目标',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        SectionTitle(
          '每日目标',
          trailing: TextButton.icon(
            onPressed: () => _editTarget('training'),
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('编辑'),
          ),
        ),
        AppCard(
          child: Column(
            children: [
              KVRow('训练日', training == null
                  ? '未设置'
                  : '${training.kcal ?? '—'} kcal · 蛋白 ${training.proteinG ?? '—'}g · 碳水 ${training.carbG ?? '—'}g · 脂肪 ${training.fatG ?? '—'}g'),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _editTarget('rest'),
                  child: const Text('设置休息日目标'),
                ),
              ),
            ],
          ),
        ),
        SectionTitle(
          '今天吃了什么',
          trailing: TextButton.icon(
            onPressed: _addMeal,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('记一餐'),
          ),
        ),
        if (_meals.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: EmptyState(
              icon: Icons.restaurant_rounded,
              title: '今天还没有记录',
              subtitle: '记一餐就能看到热量和三大营养素进度。',
            ),
          )
        else
          ..._meals.map(
            (m) => AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${slotLabel[m.slot] ?? m.slot}${m.name != null ? ' · ${m.name}' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${m.kcal} kcal · 蛋白 ${m.proteinG}g · 碳水 ${m.carbG}g · 脂肪 ${m.fatG}g',
                          style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      if (m.id == null) return;
                      await AppScope.of(context).repo.deleteMeal(m.id!);
                      _load();
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('身体'),
          bottom: const TabBar(tabs: [Tab(text: '身体数据'), Tab(text: '营养')]),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [_bodyTab(cs), _nutritionTab(cs)],
                ),
        ),
      ),
    );
  }
}
