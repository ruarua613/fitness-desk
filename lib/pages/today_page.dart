import 'package:flutter/material.dart';

import '../data/models.dart';
import '../domain/progression.dart';
import '../domain/templates.dart';
import '../scope.dart';
import '../utils.dart';
import '../widgets.dart';
import 'workout_page.dart';
import 'plans_page.dart';

/// 今日：按当前计划的周排期找到今天该练什么，给出每个动作的本次建议。
class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  bool _loading = true;
  Plan? _plan;
  TrainingDay? _day;
  WeeklySlot? _slot;
  String _version = 'full';
  final Map<String, Suggestion> _suggestions = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final scope = AppScope.of(context);
    try {
      final id = scope.settings.activePlanId;
      Plan? plan;
      if (id > 0) {
        plan = await scope.repo.getPlan(id);
      } else {
        final plans = await scope.repo.listPlans();
        if (plans.isNotEmpty) {
          plan = plans.first;
          scope.settings.activePlanId = plan.id ?? 0;
        }
      }
      if (plan == null) {
        setState(() {
          _plan = null;
          _day = null;
          _slot = null;
          _loading = false;
        });
        return;
      }

      final today = weekdayIndex(DateTime.now());
      final schedule = plan.weeklySchedule;
      WeeklySlot? slot;
      for (final s in schedule) {
        if (s.dayIndex == today) {
          slot = s;
          break;
        }
      }
      slot ??= schedule.isNotEmpty ? schedule.first : null;

      TrainingDay? day;
      if (slot?.dayId != null) {
        for (final d in plan.trainingDays) {
          if (d.id == slot!.dayId) {
            day = d;
            break;
          }
        }
      }
      day ??= plan.trainingDays.isNotEmpty ? plan.trainingDays.first : null;

      _suggestions.clear();
      if (day != null) {
        for (final e in day.exercises) {
          final history =
              await scope.repo.historyForExercise(e.id, fallbackName: e.name);
          _suggestions[e.id] = suggestNext(
            history,
            e.prescription,
            increment: scope.settings.incrementKg,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _plan = plan;
        _slot = slot;
        _day = day;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, '读取失败：$e');
    }
  }

  Future<void> _startWorkout() async {
    final day = _day;
    if (day == null) return;
    final exercises = resolveDayExercises(day, _version);
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkoutPage(
          planId: _plan?.id,
          dayId: day.id,
          dayTitle: day.title,
          version: _version,
          exercises: exercises,
        ),
      ),
    );
    if (created == true) _load();
  }

  Future<void> _freeWorkout() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const WorkoutPage(
          dayTitle: '自由训练',
          version: 'full',
          exercises: [],
        ),
      ),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _plan == null ? _buildNoPlan() : _buildBody(cs),
              ),
      ),
      floatingActionButton: _day == null
          ? FloatingActionButton.extended(
              onPressed: _freeWorkout,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('自由训练'),
            )
          : FloatingActionButton.extended(
              onPressed: _startWorkout,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('开始训练'),
            ),
    );
  }

  Widget _buildNoPlan() {
    return ListView(
      children: [
        const SizedBox(height: 40),
        EmptyState(
          icon: Icons.calendar_month_rounded,
          title: '还没有计划',
          subtitle: '先建一个计划，首页会按周排期告诉你今天练什么、每个动作做多少。',
          action: FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NewPlanPage()),
              );
              _load();
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('新建计划'),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(ColorScheme cs) {
    final plan = _plan!;
    final day = _day;
    if (day == null) {
      return ListView(
        children: const [
          SizedBox(height: 40),
          EmptyState(
            icon: Icons.event_busy_rounded,
            title: '这个计划还没有训练日',
            subtitle: '打开计划详情页确认一下内容，或者重新生成一个。',
          ),
        ],
      );
    }

    final exercises = resolveDayExercises(day, _version);
    final today = weekdayIndex(DateTime.now());
    final isToday = _slot?.dayIndex == today;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      day.title,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (!isToday)
                    InfoChip('${weekdayLabel(_slot?.dayIndex ?? today)} · 顺延',
                        color: cs.tertiary),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${day.theme} · ${day.duration}',
                style: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  InfoChip(plan.title, icon: Icons.flag_rounded, color: cs.secondary),
                  InfoChip('${exercises.length} 个动作', icon: Icons.list_alt_rounded),
                ],
              ),
            ],
          ),
        ),
        SectionTitle(
          '本次版本',
          trailing: Text(
            _version == 'full' ? '完整版，按计划做' : '时间不够时的保底方案',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ),
        Wrap(
          spacing: 8,
          children: kDayVersions.map((v) {
            final selected = v.key == _version;
            return ChoiceChip(
              label: Text(v.label),
              selected: selected,
              onSelected: (_) => setState(() => _version = v.key),
            );
          }).toList(),
        ),
        SectionTitle('动作与建议'),
        ...exercises.map((e) => _exerciseTile(cs, e)),
        const SizedBox(height: 12),
        Text(
          '建议依据上一次的实际记录按渐进规则算出：全部工作组达到次数上限且末组 RPE 不超过 7 才加重量；'
          '连续两次同重量掉次数就先维持。',
          style: TextStyle(fontSize: 12, height: 1.6, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _exerciseTile(ColorScheme cs, Exercise e) {
    final sug = _suggestions[e.id];
    final p = e.prescription;
    final color = switch (sug?.level) {
      SuggestionLevel.increase => cs.primary,
      SuggestionLevel.calibrate => cs.tertiary,
      _ => cs.outline,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  e.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (sug != null)
                InfoChip(sug.tag, color: color, icon: switch (sug.level) {
                  SuggestionLevel.increase => Icons.trending_up_rounded,
                  SuggestionLevel.calibrate => Icons.tune_rounded,
                  _ => Icons.horizontal_rule_rounded,
                }),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${p.setCount} 组 × ${p.reps} 次 · ${p.intensity} · 间歇 ${p.rest}',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          if (sug != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本次：${sug.weight != null && sug.weight! > 0 ? '${fmtWeight(sug.weight)} kg × ' : ''}${sug.reps} 次',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sug.reason,
                    style: TextStyle(fontSize: 12.5, height: 1.55, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
          if (e.techniqueChecks.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...e.techniqueChecks.take(2).map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_rounded, size: 14, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
