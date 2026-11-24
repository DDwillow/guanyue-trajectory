import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/friend_state.dart';
import '../models/friend.dart';
import '../services/friend_share_service.dart';
import '../theme/app_theme.dart';
import 'friend_analysis_screen.dart';
import 'friend_item_detail_screen.dart';

/// 单个好友的轨迹详情页：展示该好友的全部记录，支持覆盖更新、AI 分析。
class FriendDetailScreen extends StatefulWidget {
  final String friendName;
  const FriendDetailScreen({super.key, required this.friendName});

  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends State<FriendDetailScreen> {
  bool _importing = false;

  Future<void> _importUpdate() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return;
    final filePath = file.path;
    if (filePath == null) {
      _showSnack('无法读取所选文件');
      return;
    }

    setState(() => _importing = true);
    try {
      final (friendName, items) =
          await FriendShareService.instance.parseShareFile(filePath);
      if (items.isEmpty) {
        _showSnack('该分享文件里没有记录');
        return;
      }

      // 覆盖更新：解析出的好友名应与本页好友一致；不一致时提示
      if (friendName != widget.friendName) {
        _showSnack('文件来自好友「$friendName」，与当前好友「${widget.friendName}」不一致');
        return;
      }

      if (!mounted) return;
      final count = await context.read<FriendState>().importItems(
            friendName: friendName,
            items: items,
            replace: true,
          );
      _showSnack('已覆盖更新好友「$friendName」的 $count 条记录');
    } catch (e) {
      if (mounted) _showSnack('更新失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openAnalysis(List<FriendItem> items) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendAnalysisScreen(
          friendName: widget.friendName,
          items: items,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendState = context.watch<FriendState>();
    final items = friendState.itemsOf(widget.friendName);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: '覆盖更新',
            onPressed: _importing ? null : _importUpdate,
          ),
        ],
      ),
      body: items.isEmpty
          ? _emptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _header(items),
                const SizedBox(height: 12),
                ...items.map((item) => _buildItemTile(item)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openAnalysis(items),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('AI 对比分析'),
                ),
              ],
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 56, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          const Text(
            '该好友暂无记录',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _header(List<FriendItem> items) {
    final watched = items.where((e) => e.status == 'watched').length;
    final types = items.map((e) => _typeLabel(e.type)).toSet();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '共 ${items.length} 条记录',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '已看 $watched',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (types.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '类型：${types.join(' / ')}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemTile(FriendItem item) {
    final watched = item.status == 'watched';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FriendItemDetailScreen(item: item),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _itemMeta(item),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (watched && item.rating > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '★ ${item.rating}',
                    style: const TextStyle(
                      color: AppColors.star,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  String _itemMeta(FriendItem item) {
    final parts = <String>[_typeLabel(item.type)];
    if (item.creator != null && item.creator!.isNotEmpty) {
      parts.add(item.creator!);
    }
    if (item.tags.isNotEmpty) {
      parts.add(item.tags.map((t) => '#$t').join(' '));
    }
    return parts.join(' · ');
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'book':
        return '书';
      case 'movie':
        return '电影';
      case 'anime':
        return '动漫';
      case 'drama':
        return '电视剧';
      default:
        return type;
    }
  }
}
