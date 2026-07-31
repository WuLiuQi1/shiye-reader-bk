import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xxread/services/reading/content_filter_service.dart';
import 'package:xxread/widgets/side_toast.dart';

class ContentFilterRulesPage extends StatefulWidget {
  const ContentFilterRulesPage({super.key});

  @override
  State<ContentFilterRulesPage> createState() => _ContentFilterRulesPageState();
}

class _ContentFilterRulesPageState extends State<ContentFilterRulesPage> {
  final _service = const ContentFilterService();
  List<ContentFilterRule> _rules = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final rules = await _service.load();
    if (mounted) {
      setState(() {
        _rules = rules;
        _loading = false;
      });
    }
  }

  Future<void> _save(List<ContentFilterRule> rules) async {
    await _service.save(rules);
    if (mounted) setState(() => _rules = rules);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('内容过滤规则'),
      actions: [
        IconButton(
          tooltip: '恢复默认规则',
          icon: const Icon(Icons.restore_rounded),
          onPressed: _restoreDefaults,
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _editRule(),
      icon: const Icon(Icons.add_rounded),
      label: const Text('添加规则'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _rules.isEmpty
        ? const Center(child: Text('还没有过滤规则'))
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: _rules.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (_, index) {
              final rule = _rules[index];
              return Card(
                child: ListTile(
                  leading: Switch(
                    value: rule.enabled,
                    onChanged: (value) {
                      final next = [..._rules];
                      next[index] = rule.copyWith(enabled: value);
                      unawaited(_save(next));
                    },
                  ),
                  title: Text(rule.name),
                  subtitle: Text(
                    '${rule.isRegex ? '正则' : '文本'} · ${rule.replacement.isEmpty ? '删除匹配内容' : '替换为：${rule.replacement}'}\n${rule.pattern}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  onTap: () => _editRule(index),
                  trailing: IconButton(
                    tooltip: '删除',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () {
                      final next = [..._rules]..removeAt(index);
                      unawaited(_save(next));
                    },
                  ),
                ),
              );
            },
          ),
  );

  Future<void> _restoreDefaults() async {
    await _save([...ContentFilterService.defaultRules]);
    if (mounted) {
      showSideToast(
        context,
        '已恢复默认过滤规则',
        kind: SideToastKind.success,
      );
    }
  }

  Future<void> _editRule([int? index]) async {
    final current = index == null ? null : _rules[index];
    final name = TextEditingController(text: current?.name ?? '');
    final pattern = TextEditingController(text: current?.pattern ?? '');
    final replacement = TextEditingController(text: current?.replacement ?? '');
    var isRegex = current?.isRegex ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(current == null ? '添加过滤规则' : '编辑过滤规则'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '规则名称'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pattern,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '匹配内容'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: replacement,
                decoration: const InputDecoration(
                  labelText: '替换文字（留空即删除）',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('使用正则表达式'),
                value: isRegex,
                onChanged: (value) => setDialogState(() => isRegex = value),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    final ruleName = name.text.trim();
    final rulePattern = pattern.text;
    final ruleReplacement = replacement.text;
    name.dispose();
    pattern.dispose();
    replacement.dispose();
    if (saved != true || ruleName.isEmpty || rulePattern.isEmpty) return;
    if (isRegex) {
      try {
        RegExp(rulePattern);
      } catch (_) {
        if (mounted) {
          showSideToast(
            context,
            '正则表达式无效',
            kind: SideToastKind.error,
          );
        }
        return;
      }
    }
    final rule = ContentFilterRule(
      id: current?.id ?? 'custom-${DateTime.now().microsecondsSinceEpoch}',
      name: ruleName,
      pattern: rulePattern,
      replacement: ruleReplacement,
      isRegex: isRegex,
      enabled: current?.enabled ?? true,
    );
    final next = [..._rules];
    if (index == null) {
      next.add(rule);
    } else {
      next[index] = rule;
    }
    await _save(next);
  }
}
