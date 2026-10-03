import 'package:flutter/material.dart';

import '../data/models.dart';
import '../domain/assistant.dart';
import '../domain/chat_message.dart';
import '../domain/llm_client.dart';
import '../scope.dart';
import '../utils.dart';
import '../widgets.dart';

/// AI 助手聊天窗口。
/// 每轮请求都会带上最新的个人档案摘要，所以改了体重、练完一次之后它立刻知道。
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final List<ChatMsg> _msgs = starterMessages();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String _profile = '';
  bool _busy = false;
  bool _ready = false;
  static const _maxTurns = 14;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProfile());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    final scope = AppScope.of(context);
    final text = await buildProfileSummary(scope.repo, scope.settings);
    if (!mounted) return;
    setState(() {
      _profile = text;
      _ready = true;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  LlmClient _client(Settings s) => LlmClient(
        baseUrl: s.llmBaseUrl,
        apiKey: s.llmApiKey,
        model: s.llmModel,
      );

  Future<void> _send(String text) async {
    final content = text.trim();
    if (content.isEmpty || _busy) return;
    final settings = AppScope.of(context).settings;
    if (settings.llmApiKey.isEmpty) {
      showToast(context, '先在下方的模型设置里填 API Key');
      await _openConfig();
      return;
    }

    setState(() {
      _msgs.add(ChatMsg(role: 'user', content: content));
      _msgs.add(ChatMsg(role: 'assistant', content: ''));
      _busy = true;
    });
    _input.clear();
    _scrollToBottom();

    final turns = _msgs
        .take(_msgs.length - 1)
        .where((m) => m.content.trim().isNotEmpty)
        .toList();
    final history = turns.length > _maxTurns
        ? turns.sublist(turns.length - _maxTurns)
        : turns;

    try {
      final reply = await _client(settings).chat(
        system: '$assistantPersona\n\n$_profile',
        turns: history,
        onDelta: (piece) {
          if (!mounted) return;
          setState(() {
            final last = _msgs.removeLast();
            _msgs.add(last.copyWith(content: last.content + piece));
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _msgs.removeLast();
        _msgs.add(ChatMsg(role: 'assistant', content: reply.trim()));
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.removeLast();
        _msgs.add(ChatMsg(role: 'assistant', content: '$e', error: true));
        _busy = false;
      });
    }
    _scrollToBottom();
  }

  Future<void> _openConfig() => showModalBottomSheet<void>(
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
      );

  /* ------------------------------------------------------------ 保存 */

  Future<void> _savePlan(Map<String, dynamic> json) async {
    final scope = AppScope.of(context);
    Map<String, dynamic> plan;
    try {
      plan = normalizeAssistantPlan(json, settings: scope.settings);
    } catch (e) {
      showToast(context, '这个计划的结构有问题：$e');
      return;
    }
    final meta = Map<String, dynamic>.from((plan['plan_meta'] as Map?) ?? const {});
    final title = (meta['title'] as String?) ?? 'AI 计划';
    final weeks = (meta['weeks'] as num?)?.toInt() ?? 4;
    try {
      final created = await scope.repo.createPlan(
        Plan(
          title: title,
          weeks: weeks,
          startDate: todayKey(),
          status: 'active',
          planJson: plan,
          createdAt: DateTime.now(),
        ),
      );
      scope.settings.activePlanId = created.id ?? 0;
      if (!mounted) return;
      showToast(context, '《$title》已保存并设为当前计划');
    } catch (e) {
      if (!mounted) return;
      showToast(context, '保存失败：$e');
    }
  }

  Future<void> _saveDiet(Map<String, dynamic> json) async {
    final scope = AppScope.of(context);
    final repo = scope.repo;
    var meals = 0;
    var targets = 0;
    try {
      final target = json['nutrition_target'];
      if (target is Map) {
        final t = Map<String, dynamic>.from(target);
        final dayType = (t['day_type'] as String?) ?? 'training';
        await repo.upsertNutritionTarget(
          NutritionTarget(
            dayType: dayType == 'rest' ? 'rest' : 'training',
            kcal: _asInt(t['kcal']),
            proteinG: _asInt(t['protein_g']),
            carbG: _asInt(t['carb_g']),
            fatG: _asInt(t['fat_g']),
          ),
        );
        targets++;
      }
      final list = json['meals'];
      if (list is List) {
        const allowed = {'breakfast', 'lunch', 'dinner', 'snack'};
        for (final item in list) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          final slot = (m['slot'] as String?) ?? 'breakfast';
          await repo.addMeal(
            Meal(
              eatenOn: todayKey(),
              slot: allowed.contains(slot) ? slot : 'snack',
              name: (m['name'] as String?)?.trim().isEmpty == true
                  ? null
                  : (m['name'] as String?)?.trim(),
              kcal: _asInt(m['kcal']) ?? 0,
              proteinG: _asInt(m['protein_g']) ?? 0,
              carbG: _asInt(m['carb_g']) ?? 0,
              fatG: _asInt(m['fat_g']) ?? 0,
            ),
          );
          meals++;
        }
      }
      if (!mounted) return;
      showToast(context, '已保存：${targets > 0 ? '营养目标、' : ''}$meals 餐记录');
    } catch (e) {
      if (!mounted) return;
      showToast(context, '保存失败：$e');
    }
  }

  int? _asInt(dynamic v) => v is num ? v.round() : int.tryParse('$v');

  /* ------------------------------------------------------------ UI */

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = AppScope.of(context).settings;
    final configured = settings.llmApiKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: '模型设置',
            onPressed: _openConfig,
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'clear') {
                setState(() {
                  _msgs.clear();
                  _msgs.addAll(starterMessages());
                });
              } else if (v == 'refresh') {
                await _refreshProfile();
                if (mounted) showToast(context, '已重新读取你的最新数据');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'refresh', child: Text('刷新我的数据')),
              PopupMenuItem(value: 'clear', child: Text('清空对话')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!configured)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: MaterialBanner(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  content: const Text('还没填模型 API Key。手机上推荐用「豆包」，'
                      '去火山方舟控制台建一个推理接入点，把接入点 ID 和 Key 填进去即可。'),
                  leading: Icon(Icons.key_rounded, color: cs.primary),
                  actions: [
                    TextButton(
                      onPressed: _openConfig,
                      child: const Text('去设置'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: _msgs.length,
                itemBuilder: (_, i) => _bubble(cs, _msgs[i]),
              ),
            ),
            if (_msgs.length <= 2) _suggestions(cs),
            const Divider(height: 1),
            _inputBar(cs),
          ],
        ),
      ),
    );
  }

  Widget _suggestions(ColorScheme cs) {
    const items = [
      '按我这周能练 3 天，排一份训练计划',
      '根据我的体重做一份减脂饮食方案',
      '深蹲膝盖不舒服，换什么动作',
      '最近两次都掉次数，要不要降重量',
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: items
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(t),
                  avatar: const Icon(Icons.auto_awesome_rounded, size: 15),
                  onTap: () => _input.text = t,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _inputBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              decoration: const InputDecoration(
                hintText: '说说你的情况，或者直接要一份计划',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _busy ? null : () => _send(_input.text),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ColorScheme cs, ChatMsg msg) {
    final isUser = msg.isUser;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isUser ? cs.primaryContainer : cs.surfaceContainerHighest;
    final textColor = isUser ? cs.onPrimaryContainer : cs.onSurface;
    final blocks = isUser ? <AssistantBlock>[] : extractBlocks(msg.content);

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.86,
          ),
          decoration: BoxDecoration(
            color: msg.error ? cs.errorContainer : color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
            ),
          ),
          child: msg.content.isEmpty
              ? const SizedBox(
                  width: 22,
                  height: 16,
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : SelectableText(
                  _display(msg.content),
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.62,
                    color: msg.error ? cs.onErrorContainer : textColor,
                  ),
                ),
        ),
        ...blocks.map((b) => _blockActions(cs, b)),
      ],
    );
  }

  /// 把 JSON 代码块收起来，界面上留一句提示就够了
  String _display(String raw) {
    final hidden = raw.replaceAllMapped(
      RegExp(r'```(\w+)?\s*([\s\S]*?)```', dotAll: true),
      (m) {
        final lang = (m.group(1) ?? '').toLowerCase();
        if (lang == 'plan') return '\n〔已生成训练计划，点下面的按钮保存〕\n';
        if (lang == 'diet') return '\n〔已生成饮食方案，点下面的按钮保存〕\n';
        return '\n〔结构化结果，见下方按钮〕\n';
      },
    );
    return hidden.trim();
  }

  Widget _blockActions(ColorScheme cs, AssistantBlock block) {
    if (block.kind == 'plan') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FilledButton.icon(
          onPressed: () => _savePlan(block.json),
          icon: const Icon(Icons.playlist_add_check_rounded),
          label: const Text('保存为训练计划'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: () => _saveDiet(block.json),
            icon: const Icon(Icons.restaurant_rounded),
            label: const Text('保存饮食方案'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _saveTargetOnly(block.json),
            icon: const Icon(Icons.flag_rounded),
            label: const Text('只存目标'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTargetOnly(Map<String, dynamic> json) async {
    await _saveDiet({'nutrition_target': json['nutrition_target']});
  }
}

/// 模型配置表单。「我的」页和助手页共用。
class LlmConfigForm extends StatefulWidget {
  const LlmConfigForm({super.key});

  @override
  State<LlmConfigForm> createState() => _LlmConfigFormState();
}

class _LlmConfigFormState extends State<LlmConfigForm> {
  late final TextEditingController _base;
  late final TextEditingController _key;
  late final TextEditingController _model;

  @override
  void initState() {
    super.initState();
    final s = AppScope.of(context).settings;
    _base = TextEditingController(text: s.llmBaseUrl);
    _key = TextEditingController(text: s.llmApiKey);
    _model = TextEditingController(text: s.llmModel);
  }

  @override
  void dispose() {
    _base.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  void _apply(LlmPreset p) {
    setState(() {
      _base.text = p.baseUrl;
    });
    showToast(context, '${p.name}：地址已填，${p.modelHint}');
  }

  void _save() {
    final s = AppScope.of(context).settings;
    s.llmBaseUrl = _base.text.trim();
    s.llmApiKey = _key.text.trim();
    s.llmModel = _model.text.trim().isEmpty ? 'deepseek-chat' : _model.text.trim();
    Navigator.of(context).pop();
    showToast(context, '已保存');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '接入大模型',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'App 只跟你自己填的服务地址通信，训练数据也不会自动上传——'
          '每次提问只会带上一段摘要（最近体重、近期训练、当前计划、今日饮食）。',
          style: TextStyle(fontSize: 12.5, height: 1.55, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: kLlmPresets.map(
            (p) => ActionChip(
              label: Text(p.name),
              onPressed: () => _apply(p),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _base,
          decoration: const InputDecoration(labelText: '接口地址'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _model,
          decoration: const InputDecoration(
            labelText: '模型 / 接入点 ID',
            helperText: '火山方舟这里填 ep-xxxxx，DeepSeek 填 deepseek-chat',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _key,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'API Key'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _save, child: const Text('保存')),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
