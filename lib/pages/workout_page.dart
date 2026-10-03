import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../domain/catalog.dart';
import '../domain/progression.dart';
import '../scope.dart';
import '../utils.dart';
import '../widgets.dart';

/// 训练执行页：一个动作一组一行，填重量 / 次数 / RPE，结束时一次性入库。
class WorkoutPage extends StatefulWidget {
  final int? planId;
  final String? dayId;
  final String dayTitle;
  final String version;
  final List<Exercise> exercises;

  const WorkoutPage({
    super.key,
    this.planId,
    this.dayId,
    required this.dayTitle,
    required this.version,
    required this.exercises,
  });

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _SetRow {
  final TextEditingController weight = TextEditingController();
  final TextEditingController reps = TextEditingController();
  final TextEditingController rpe = TextEditingController();
  bool done = false;
  bool warmup = false;

  bool get hasValue => weight.text.trim().isNotEmpty || reps.text.trim().isNotEmpty;

  void dispose() {
    weight.dispose();
    reps.dispose();
    rpe.dispose();
  }
}

class _ExEntry {
  final Exercise ex;
  final List<_SetRow> rows;
  _ExEntry(this.ex, this.rows);

  void dispose() {
    for (final r in rows) {
      r.dispose();
    }
  }
}

class _WorkoutPageState extends State<WorkoutPage> {
  final List<_ExEntry> _entries = [];
  WorkoutSession? _session;
  final DateTime _started = DateTime.now();
  final TextEditingController _note = TextEditingController();
  bool _saving = false;
  int _restSeconds = 0;
  Timer? _timer;
  final ValueNotifier<int> _restLeft = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final scope = AppScope.of(context);
    final session = await scope.repo.createSession(
      WorkoutSession(
        planId: widget.planId,
        dayId: widget.dayId,
        dayTitle: widget.dayTitle,
        version: widget.version,
        status: 'in_progress',
        performedOn: todayKey(),
      ),
    );
    if (!mounted) return;
    _session = session;

    final built = <_ExEntry>[];
    for (final e in widget.exercises) {
      final history = await scope.repo.historyForExercise(e.id, fallbackName: e.name);
      final sug = suggestNext(history, e.prescription, increment: scope.settings.incrementKg);
      final rows = <_SetRow>[];
      for (var i = 0; i < e.prescription.setCount; i++) {
        final r = _SetRow();
        if (sug.weight != null && sug.weight! > 0) {
          r.weight.text = fmtWeight(sug.weight);
        }
        r.reps.text = '${sug.reps}';
        rows.add(r);
      }
      built.add(_ExEntry(e, rows));
    }
    if (!mounted) return;
    setState(() => _entries.addAll(built));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restLeft.dispose();
    _note.dispose();
    for (final en in _entries) {
      en.dispose();
    }
    super.dispose();
  }

  void _addExercise(Exercise e) {
    final rows = <_SetRow>[];
    for (var i = 0; i < e.prescription.setCount; i++) {
      rows.add(_SetRow());
    }
    setState(() => _entries.add(_ExEntry(e, rows)));
  }

  void _addSet(_ExEntry en) {
    setState(() => en.rows.add(_SetRow()));
  }

  void _startRest(int seconds) {
    _timer?.cancel();
    _restSeconds = seconds;
    _restLeft.value = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_restLeft.value <= 1) {
        t.cancel();
        _restLeft.value = 0;
        return;
      }
      _restLeft.value = _restLeft.value - 1;
    });
  }

  Future<void> _finish() async {
    final session = _session;
    if (session == null || session.id == null) return;
    final scope = AppScope.of(context);
    final sets = <SetLog>[];
    for (final en in _entries) {
      var index = 0;
      for (final r in en.rows) {
        if (!r.hasValue) continue;
        index++;
        sets.add(SetLog(
          sessionId: session.id!,
          exerciseKey: en.ex.id,
          exerciseName: en.ex.name,
          setIndex: index,
          weight: parseDouble(r.weight.text),
          reps: parseInt(r.reps.text),
          rpe: parseDouble(r.rpe.text),
          isWarmup: r.warmup,
        ));
      }
    }
    if (sets.isEmpty) {
      showToast(context, '至少记录一组再结束');
      return;
    }

    setState(() => _saving = true);
    try {
      await scope.repo.insertSets(sets);
      final minutes = DateTime.now().difference(_started).inMinutes;
      await scope.repo.updateSession(
        WorkoutSession(
          id: session.id,
          planId: session.planId,
          dayId: session.dayId,
          dayTitle: session.dayTitle,
          version: session.version,
          status: 'completed',
          performedOn: session.performedOn,
          durationMin: minutes < 1 ? 1 : minutes,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, '保存失败：$e');
    }
  }

  Future<bool> _onWillPop() async {
    if (_session == null) return true;
    final ok = await askConfirm(context, '放弃这次训练？', '已经记录的组不会被保存。');
    if (ok) {
      await AppScope.of(context).repo.deleteSession(_session!.id!);
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _onWillPop();
        if (ok && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.dayTitle),
          actions: [
            TextButton.icon(
              onPressed: _saving ? null : _finish,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('完成'),
            ),
          ],
        ),
        bottomNavigationBar: _restBar(cs),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _pickExercise,
          icon: const Icon(Icons.add_rounded),
          label: const Text('加动作'),
        ),
        body: SafeArea(
          child: _session == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  children: [
                    if (_entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyState(
                          icon: Icons.fitness_center_rounded,
                          title: '还没有动作',
                          subtitle: '点右下角从动作库里挑，或者自由训练时直接记录。',
                        ),
                      ),
                    for (final en in _entries) _exerciseCard(cs, en),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: TextField(
                          controller: _note,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: '训练备注（可选）',
                            hintText: '状态、睡眠、哪里不舒服…',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _restBar(ColorScheme cs) {
    return ValueListenableBuilder<int>(
      valueListenable: _restLeft,
      builder: (context, left, _) {
        final running = left > 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
          ),
          child: Row(
            children: [
              Icon(
                running ? Icons.timer_rounded : Icons.timer_outlined,
                size: 18,
                color: running ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                running ? '休息中 ${left}s' : '组间歇计时',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: running ? FontWeight.w700 : FontWeight.w500,
                  color: running ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  if (running) {
                    _timer?.cancel();
                    _restLeft.value = 0;
                  } else {
                    _startRest(_restSeconds > 0 ? _restSeconds : 90);
                  }
                },
                child: Text(running ? '结束' : '开始 90 秒'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _exerciseCard(ColorScheme cs, _ExEntry en) {
    final p = en.ex.prescription;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  en.ex.name,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline_rounded),
                tooltip: '加一组',
                onPressed: () => _addSet(en),
              ),
            ],
          ),
          Text(
            '目标 ${p.setCount} 组 × ${p.reps} 次 · ${p.intensity} · 间歇 ${p.rest}',
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
          ),
          if (en.ex.startingInstruction.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              en.ex.startingInstruction,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 10),
          ...en.rows.asMap().entries.map((me) => _setRow(cs, en, me.key, me.value)),
        ],
      ),
    );
  }

  Widget _setRow(ColorScheme cs, _ExEntry en, int i, _SetRow r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${i + 1}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: r.weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '重量',
                suffixText: 'kg',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: r.reps,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '次数',
                suffixText: '次',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: r.rpe,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'RPE',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              r.done ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
              color: r.done ? cs.primary : cs.onSurfaceVariant,
            ),
            tooltip: '这组完成',
            onPressed: () {
              setState(() => r.done = !r.done);
              if (r.done) {
                final secs = en.ex.prescription.restSeconds;
                _startRest(secs > 0 ? secs : 90);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickExercise() async {
    final picked = await showModalBottomSheet<CatalogEntry>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, ctl) => ListView(
          controller: ctl,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Text(
                '从动作库添加',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            ...kCatalog.map(
              (c) => ListTile(
                title: Text(c.name),
                subtitle: Text('${c.pattern} · ${c.equipment} · ${c.setCount}×${c.repsMin}-${c.repsMax}'),
                onTap: () => Navigator.pop(ctx, c),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      _addExercise(place('free', picked.key));
    }
  }
}
