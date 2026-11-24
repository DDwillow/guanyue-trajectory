import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_state.dart';
import '../data/settings_service.dart';
import '../services/ai_service.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';

/// 设置页：用户名、副标题显示、AI 补全、备份
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _keyCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  bool _exporting = false;
  bool _importing = false;
  SubtitleField _subtitleField = SubtitleField.time;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await AiService.instance.getApiKey();
    final subtitle = await SettingsService.instance.getSubtitleField();
    final username = await SettingsService.instance.getUsername();
    if (mounted) {
      setState(() {
        _keyCtrl.text = key ?? '';
        _subtitleField = subtitle;
        _usernameCtrl.text = username ?? '';
        _loaded = true;
      });
    }
  }

  Future<void> _save() async {
    final key = _keyCtrl.text.trim();
    setState(() => _saving = true);
    await AiService.instance.saveApiKey(key);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(key.isEmpty ? '已清空 API Key' : '已保存 API Key'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveUsername() async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) {
      await SettingsService.instance.setUsername('');
      _showSnack('已清空用户名');
      return;
    }
    if (username.length > 16) {
      _showSnack('用户名不能超过 16 个汉字');
      return;
    }
    await SettingsService.instance.setUsername(username);
    _showSnack('已保存用户名');
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final path = await BackupService.instance.exportAll();
      if (mounted) {
        _showSnack('备份成功');
        // 弹出系统分享
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path)],
            text: '观阅轨迹数据备份',
          ),
        );
      }
    } catch (e) {
      if (mounted) _showSnack('备份失败：$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    // 调用系统文件管理器选择备份文件
    final file = await FilePicker.pickFile(
      type: FileType.any,
    );
    if (file == null) return;

    final filePath = file.path;
    if (filePath == null) {
      _showSnack('无法读取所选文件');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入备份'),
        content: const Text('导入将覆盖当前所有数据，确定继续吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('导入', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _importing = true);
    try {
      final count = await BackupService.instance.importFromFile(filePath);
      if (mounted) {
        await context.read<AppState>().load();
        _showSnack('导入成功，共 $count 条记录');
      }
    } catch (e) {
      if (mounted) _showSnack('导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('用户'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '用户名',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '最多 16 个汉字',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _usernameCtrl,
                        maxLength: 16,
                        decoration: InputDecoration(
                          hintText: '输入你的用户名',
                          counterText: '',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saveUsername,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('保存', style: TextStyle(fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('副标题显示'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '首页作品名下方优先显示',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...SubtitleField.values.map((field) {
                        return RadioListTile<SubtitleField>(
                          value: field,
                          groupValue: _subtitleField,
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _subtitleField = v);
                            SettingsService.instance.setSubtitleField(v);
                          },
                          title: Text(
                            field.label,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            field.desc,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          activeColor: AppColors.accent,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('AI 补全'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DeepSeek API Key',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '填写后即可在编辑页使用「AI 补全」，自动补充作者/导演、主演、简介等信息。',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _keyCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'sk-...',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.visibility_outlined),
                            onPressed: () {
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _saving ? '保存中...' : '保存',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('备份'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '导出或导入全部数据（记录 + 标签库）',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _exporting ? null : _export,
                              icon: _exporting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.upload_outlined, size: 18),
                              label: Text(_exporting ? '导出中...' : '导出备份'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: const BorderSide(color: AppColors.accent),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _importing ? null : _import,
                              icon: _importing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.download_outlined, size: 18),
                              label: Text(_importing ? '导入中...' : '导入备份'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: const BorderSide(color: AppColors.accent),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('关于'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '观阅轨迹',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '记录看过的书、电影与动漫。',
                        style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
