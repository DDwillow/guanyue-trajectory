import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/settings_service.dart';
import '../models/friend.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

/// 好友 AI 报告分析页
class FriendAnalysisScreen extends StatefulWidget {
  final String friendName;
  final List<FriendItem> items;
  const FriendAnalysisScreen({
    super.key,
    required this.friendName,
    required this.items,
  });

  @override
  State<FriendAnalysisScreen> createState() => _FriendAnalysisScreenState();
}

class _FriendAnalysisScreenState extends State<FriendAnalysisScreen> {
  bool _loading = false;
  String? _result;

  Future<void> _analyze() async {
    final app = context.read<AppState>();
    final myItems = app.items.toList();
    final friendItems = widget.items.toList();
    final myName = await SettingsService.instance.getUsername() ?? '';

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final text = await AiService.instance.analyzeFriend(
        friendName: widget.friendName,
        myName: myName,
        friendItems: friendItems.map((e) => e.toItem()).toList(),
        myItems: myItems,
      );
      if (mounted) setState(() => _result = text);
    } on AiException catch (e) {
      if (mounted) _showSnack(e.message);
    } catch (e) {
      if (mounted) _showSnack('分析失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('好友对比分析'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _introCard(),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('AI 正在分析...', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else if (_result == null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _analyze,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('开始分析'),
              ),
            )
          else ...[
            _resultCard(_result!),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _analyze,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重新分析'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.accentDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI 将以第三人称，客观对比好友「${widget.friendName}」与你的观影/阅读轨迹，系统分析偏好画像、重合度、相近偏好，并给出推荐。',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(String text) {
    // 简单解析 markdown 小标题为富文本（**标题** 加粗）
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _renderMarkdown(text),
    );
  }

  Widget _renderMarkdown(String text) {
    // 按空行/换行分段，段内解析 **小标题** 加粗
    final blocks = text
        .split(RegExp(r'\n\s*\n'))
        .where((b) => b.trim().isNotEmpty)
        .toList();

    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i].trim();
      // 解析 **加粗**
      final spans = <TextSpan>[];
      final parts = block.split(RegExp(r'(\*\*[^*]+\*\*)'));
      for (final part in parts) {
        if (part.isEmpty) continue;
        if (part.startsWith('**') && part.endsWith('**')) {
          spans.add(TextSpan(
            text: part.substring(2, part.length - 2),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ));
        } else {
          spans.add(TextSpan(text: part));
        }
      }

      final isHeading = block.startsWith('**');
      children.add(Container(
        margin: EdgeInsets.only(top: i == 0 ? 0 : 14),
        child: Text.rich(
          TextSpan(
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.7,
              fontWeight: isHeading ? FontWeight.w700 : FontWeight.normal,
            ),
            children: spans,
          ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
