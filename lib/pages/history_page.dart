import 'package:flutter/material.dart';

import '../data/models.dart';
import '../domain/catalog.dart';
import '../domain/progression.dart';
import '../scope.dart';
import '../utils.dart';
import '../widgets.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _loading = true;
  List<WorkoutSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final list = await AppScope.of(context).repo.listSessions(limit: 120);
    if (!mounted) return;
    setState(() {
      _sessions = list;
      _loading = false;
    });
  }

  Future<void> _open(WorkoutSession s) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: s.id ?? 0)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final weekStart = weekStartKey();
    final thisWeek = _sessions.where((s) => s.performedOn.compareTo(weekStart) >= 0).length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('历史'),
          bottom: const TabBar(tabs: [Tab(text: '训练记录'), Tab(text: '动作进展')]),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _sessions.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 40),
                                EmptyState(
                                  icon: Icons.history_rounded,
                                  title: '还没有训练记录',
                                  subtitle: '完成一次训练后，这里会按时间倒序列出来。',
                                ),
                              ],
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                              children: [
                                Row(
                                  children: [
                                    StatTile(label: '本周完成', value: '$thisWeek', unit: '次',
                                        icon: Icons.check_circle_rounded),
                                    const SizedBox(width: 10),
                                    StatTile(label: '累计', value: '${_sessions.length}', unit: '次',
                                        icon: Icons.flag_rounded),
                                  ],
                                ),
                                const SectionTitle('全部记录'),
                                ..._sessions.map(
                                  (s) => AppCard(
                                    onTap: () => _open(s),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s.dayTitle,
                                                style: TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: cs.onSurface,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${friendlyDate(s.performedOn)}'
                                                '${s.durationMin != null ? ' · ${s.durationMin} 分钟' : ''}',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (s.version != 'full')
                                          InfoChip(
                                            switch (s.version) {
                                              'minutes_30' => '30 分钟版',
                                              'minutes_20' => '20 分钟版',
                                              'minutes_10' => '10 分钟版',
                                              _ => s.version,
                                            },
                                            color: cs.tertiary,
                                          ),
                                        const SizedBox(width: 6),
                                        Icon(Icons.chevron_right_rounded,
                                            color: cs.onSurfaceVariant),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
              const ProgressTab(),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------ 单次详情 */

class SessionDetailPage extends StatefulWidget {
  final int sessionId;
  const SessionDetailPage({super.key, required this.sessionId});

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  bool _loading = true;
  WorkoutSession? _session;
  List<SetLog> _sets = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = AppScope.of(context).repo;
    final all = await repo.listSessions(limit: 500);
    WorkoutSession? found;
    for (final s in all) {
      if (s.id == widget.sessionId) {
        found = s;
        break;
      }
    }
    final sets = await repo.listSets(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _session = found;
      _sets = sets;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = _session;
    final groups = <String, List<SetLog>>{};
    for (final set in _sets) {
      groups.putIfAbsent(set.exerciseName, () => []).add(set);
    }
    var totalVolume = 0.0;
    for (final set in _sets) {
      totalVolume += (set.weight ?? 0) * (set.reps ?? 0);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s?.dayTitle ?? '训练记录'),
        actions: [
          if (s != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final ok = await askConfirm(context, '删除这次记录？', '删除后无法恢复。');
                if (ok) {
                  await AppScope.of(context).repo.deleteSession(s.id!);
                  if (mounted) Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  Row(
                    children: [
                      StatTile(label: '组数', value: '${_sets.length}', unit: '组'),
                      const SizedBox(width: 10),
                      StatTile(
                        label: '总容量',
                        value: fmtQty(totalVolume),
                        unit: 'kg',
                        icon: Icons.monitor_weight_rounded,
                      ),
                    ],
                  ),
                  if (s?.note != null && s!.note!.isNotEmpty) ...[
                    const SectionTitle('备注'),
                    AppCard(child: Text(s.note!)),
                  ],
                  const SectionTitle('动作明细'),
                  ...groups.entries.map(
                    (g) => AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.key,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...g.value.map(
                            (set) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 30,
                                    child: Text(
                                      '${set.setIndex}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    set.weight != null ? '${fmtWeight(set.weight)} kg' : '自重',
                                    style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${set.reps ?? 0} 次',
                                    style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                                  ),
                                  const Spacer(),
                                  if (set.rpe != null)
                                    Text(
                                      'RPE ${fmtWeight(set.rpe)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  if (set.isWarmup) ...[
                                    const SizedBox(width: 8),
                                    InfoChip('热身', color: cs.tertiary),
                                  ],
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

/* ------------------------------------------------------------ 进展 */

class _Candidate {
  final String key;
  final String name;
  _Candidate(this.key, this.name);
}

class ProgressTab extends StatefulWidget {
  const ProgressTab({super.key});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  bool _loading = true;
  List<_Candidate> _candidates = [];
  _Candidate? _picked;
  List<ExerciseHistory> _history = [];
  Suggestion? _sug;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final repo = AppScope.of(context).repo;
    final plans = await repo.listPlans();
    final seen = <String, String>{};
    for (final p in plans) {
      for (final d in p.trainingDays) {
        for (final e in d.exercises) {
          seen.putIfAbsent(e.id, () => e.name);
        }
      }
    }
    for (final c in kCatalog) {
      seen.putIfAbsent('free-${c.key}', () => c.name);
    }
    final candidates = seen.entries.map((e) => _Candidate(e.key, e.value)).toList();
    candidates.sort((a, b) => a.name.compareTo(b.name));

    if (!mounted) return;
    setState(() {
      _candidates = candidates;
      _loading = false;
    });
  }

  Future<void> _pick(_Candidate c) async {
    final repo = AppScope.of(context).repo;
    final history = await repo.historyForExercise(c.key, fallbackName: c.name);
    final sug = suggestNext(
      history,
      const Prescription(
        setCount: 3,
        reps: '8—12',
        repsMin: 8,
        repsMax: 12,
        intensity: 'RPE 6—7',
        rest: '90 秒',
        restSeconds: 90,
      ),
      increment: AppScope.of(context).settings.incrementKg,
    );
    if (!mounted) return;
    setState(() {
      _picked = c;
      _history = history;
      _sug = sug;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        const SectionTitle('选动作'),
        Wrap(
          spacing: 8,
          children: _candidates
              .map(
                (c) => ChoiceChip(
                  label: Text(c.name),
                  selected: _picked?.key == c.key,
                  onSelected: (_) => _pick(c),
                ),
              )
              .toList(),
        ),
        if (_picked == null)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyState(
              icon: Icons.insights_rounded,
              title: '选一个动作看曲线',
              subtitle: '这里按动作聚合历史记录，给出下一次的建议。',
            ),
          )
        else ...[
          const SectionTitle('峰值重量'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_history.isEmpty)
                  Text(
                    '这个动作还没有记录。',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  )
                else ...[
                  SparkLine(
                    values: progressionSeries(_history).map((p) => p.weight).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        shortDate(_history.first.date),
                        style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                      ),
                      Text(
                        shortDate(_history.last.date),
                        style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_sug != null) ...[
            const SectionTitle('下次建议'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoChip(
                    _sug!.tag,
                    color: switch (_sug!.level) {
                      SuggestionLevel.increase => cs.primary,
                      SuggestionLevel.calibrate => cs.tertiary,
                      _ => cs.outline,
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sug!.weight != null && _sug!.weight! > 0
                        ? '${fmtWeight(_sug!.weight)} kg × ${_sug!.reps} 次'
                        : '${_sug!.reps} 次',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _sug!.reason,
                    style: TextStyle(fontSize: 12.5, height: 1.6, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
          if (_history.isNotEmpty) ...[
            const SectionTitle('逐次记录'),
            ..._history.reversed.take(8).map(
                  (h) => AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friendlyDate(h.date),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          h.sets
                              .map((s) => s.weight != null
                                  ? '${fmtWeight(s.weight)}×${s.reps ?? 0}'
                                  : '${s.reps ?? 0}')
                              .join('  '),
                          style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ],
    );
  }
}
