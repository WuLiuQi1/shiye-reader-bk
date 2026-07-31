import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xxread/services/sync/icloud_backup_service.dart';

class ICloudBackupPage extends StatefulWidget {
  const ICloudBackupPage({super.key});

  @override
  State<ICloudBackupPage> createState() => _ICloudBackupPageState();
}

class _ICloudBackupPageState extends State<ICloudBackupPage> {
  final _service = ICloudBackupService();
  ICloudBackupInfo? _info;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final info = await _service.backupInfo();
      if (mounted) setState(() => _info = info);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('iCloud 备份')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.cloud_outlined),
          title: Text('备份内容'),
          subtitle: Text('书源、书架和阅读进度。不会备份小说正文、封面和缓存。'),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('最后备份'),
          subtitle: Text(
            _error ??
                (_info == null
                    ? '尚无备份'
                    : '${_format(_info!.createdAt.toLocal())} · ${_info!.bookCount} 本书'),
          ),
          trailing: _busy
              ? const CircularProgressIndicator()
              : const Icon(Icons.info_outline),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy ? null : _backup,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('立即备份'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy || _info == null ? null : _restore,
          icon: const Icon(Icons.cloud_download_outlined),
          label: const Text('从 iCloud 恢复'),
        ),
      ],
    ),
  );

  Future<void> _backup() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final info = await _service.backup();
      if (!mounted) return;
      setState(() => _info = info);
      _show('备份成功');
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从 iCloud 恢复？'),
        content: const Text('恢复会覆盖当前书源、书架和阅读进度。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _service.restore();
      if (mounted) _show('恢复成功，请返回书架查看');
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _format(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
