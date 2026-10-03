import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/models.dart';
import '../scope.dart';
import '../utils.dart';
import '../widgets.dart';
import 'assistant_page.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  bool _loading = true;
  int _sessionsThisWeek = 0;
  int _plannedPerWeek = 0;
  double _avgRpe = 0;
  WeeklyReview? _review;
  final TextEditingController _note = TextEditingController();
  double _sleep = 3;
  double _soreness = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final scope = AppScope.of(context);
    final repo = scope.repo;
    final weekStart = weekStartKey();

    final sessions = await repo.listSessions(limit: 200);
    final thisWeek = sessions.where((s) => s.performedOn.compareTo(weekStart) >= 0).toList();

    var planned = 0;
    final activeId = scope.settings.activePlanId;
    if (activeId > 0) {
      final plan = await repo.getPlan(activeId);
      planned = plan?.weeklySchedule.length ?? 0;
    }

    double rpeSum = 0;
    int rpeCount = 0;
    for (final s in thisWeek) {
      final sets = await repo.listSets(s.id ?? 0);
      for (final set in sets) {
        if (set.rpe != null && set.rpe! > 0) {
          rpeSum += set.rpe!;
          rpeCount++;
        }
      }
    }

    final reviews = await repo.listWeeklyReviews(limit: 60);
    WeeklyReview? current;
    for (final r in reviews) {
      if (r.weekStart == weekStart) {
        current = r;
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _sessionsThisWeek = thisWeek.length;
      _plannedPerWeek = planned;
      _avgRpe = rpeCount > 0 ? rpeSum / rpeCount : 0;
      _review = current;
      _note.text = current?.note ?? '';
      _sleep = (current?.sleepQuality ?? 3).toDouble();
      _soreness = (current?.soreness ?? 3).toDouble();
      _loading = false;
    });
  }

  Future<void> _saveReview() async {
    final repo = AppScope.of(context).repo;
    final pct = _plannedPerWeek > 0
        ? (_sessionsThisWeek / _plannedPerWeek * 100).clamp(0, 100).toDouble()
        : null;
    await repo.upsertWeeklyReview(
      WeeklyReview(
        id: _review?.id,
        weekStart: weekStartKey(),
        completionPct: pct,
        avgRpe: _avgRpe > 0 ? _avgRpe : null,
        sleepQuality: _sleep.round(),
        soreness: _soreness.round(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
    if (!mounted) return;
    showToast(context, '本周复盘已保存');
    _load();
  }

  Future<void> _export() async {
    final repo = AppScope.of(context).repo;
    final data = await repo.exportAll();
    final text = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'fitness-export-${todayKey()}.json'));
    await file.writeAsString(text);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('已导出'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('文件已写到手机存储：'),
            const SizedBox(height: 8),
            SelectableText(file.path, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(ctx);
              showToast(context, '已复制到剪贴板');
            },
            child: const Text('复制内容'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    final ctrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '导入数据',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '粘贴之前导出的 JSON。导入会覆盖同 id 的记录。',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: TextField(
                controller: ctrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(hintText: '{"format": "fitness-desk-export", ...}'),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('导入'),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) {
      ctrl.dispose();
      return;
    }
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (text.isEmpty) return;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) throw const FormatException('顶层必须是对象');
      await AppScope.of(context).repo.importAll(Map<String, dynamic>.from(decoded));
      if (!mounted) return;
      showToast(context, '导入完成');
      _load();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '导入失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scope = AppScope.of(context);
    final increment = scope.settings.incrementKg;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: [
                    Row(
                      children: [
                        StatTile(
                          label: '本周完成',
                          value: '$_sessionsThisWeek',
                          unit: _plannedPerWeek > 0 ? '/ $_plannedPerWeek' : '次',
                          icon: Icons.check_circle_rounded,
                        ),
                        const SizedBox(width: 10),
                        StatTile(
                          label: '平均 RPE',
                          value: _avgRpe > 0 ? fmtQty(_avgRpe) : '—',
                        ),
                      ],
                    ),
                    const SectionTitle('本周复盘'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '睡眠 ${_sleep.round()} / 5',
                            style: TextStyle(fontSize: 13, color: cs.onSurface),
                          ),
                          Slider(
                            value: _sleep,
                            min: 1,
                            max: 5,
                            divisions: 4,
                            label: '${_sleep.round()}',
                            onChanged: (v) => setState(() => _sleep = v),
                          ),
                          Text(
                            '酸痛 ${_soreness.round()} / 5',
                            style: TextStyle(fontSize: 13, color: cs.onSurface),
                          ),
                          Slider(
                            value: _soreness,
                            min: 1,
                            max: 5,
                            divisions: 4,
                            label: '${_soreness.round()}',
                            onChanged: (v) => setState(() => _soreness = v),
                          ),
                          TextField(
                            controller: _note,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: '本周备注',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saveReview,
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('保存复盘'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SectionTitle('训练设置'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '加重单位',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '决定「可以加重」时一次加多少。杠铃动作通常用 2.5，哑铃或小肌群可以用 1.25。',
                            style: TextStyle(fontSize: 12.5, height: 1.5, color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [1.25, 2.5, 5.0, 10.0].map((v) {
                              return ChoiceChip(
                                label: Text('${fmtWeight(v)} kg'),
                                selected: (increment - v).abs() < 0.001,
                                onSelected: (_) {
                                  AppScope.of(context).settings.incrementKg = v;
                                  setState(() {});
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SectionTitle('AI 助手'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '每次提问会带上你的体重围度、近期训练、当前计划和今日饮食的摘要。'
                            'App 只跟你填的那个接口通信。',
                            style: TextStyle(fontSize: 12.5, height: 1.55, color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.auto_awesome_rounded),
                            title: const Text('模型接口'),
                            subtitle: Text(
                              scope.settings.hasLlm
                                  ? '${scope.settings.llmBaseUrl}\n${scope.settings.llmModel}'
                                  : '未配置，点这里填 Key',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: true,
                              builder: (ctx) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                                  left: 16,
                                  right: 16,
                                  top: 8,
                                ),
                                child: const SingleChildScrollView(child: LlmConfigForm()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SectionTitle('数据'),
                    AppCard(
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.upload_file_rounded),
                            title: const Text('导出全部数据'),
                            subtitle: const Text('写成 JSON 文件，可复制或分享出去'),
                            onTap: _export,
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.download_rounded),
                            title: const Text('导入数据'),
                            subtitle: const Text('粘贴导出的 JSON'),
                            onTap: _import,
                          ),
                        ],
                      ),
                    ),
                    const SectionTitle('关于'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          KVRow('形态', 'Flutter 原生应用（Dart + Material 3）'),
                          KVRow('存储', '本机 SQLite，不联网、不上传'),
                          KVRow('同步', '接口已预留，当前未接入远端'),
                          const SizedBox(height: 8),
                          Text(
                            '计划结构对齐 plan-contract：周排期、训练日、动作处方、最短版本、渐进规则、'
                            '中断规则与复盘节点。安全边界写在计划里，出现胸痛、晕厥、异常气短或持续加重的疼痛就停止。',
                            style: TextStyle(fontSize: 12.5, height: 1.6, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
