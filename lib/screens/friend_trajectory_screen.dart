import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/friend_state.dart';
import '../models/friend.dart';
import '../services/friend_share_service.dart';
import '../theme/app_theme.dart';
import 'friend_detail_screen.dart';

/// 好友轨迹：按好友名分类展示导入的好友记录
class FriendTrajectoryScreen extends StatefulWidget {
  const FriendTrajectoryScreen({super.key});

  @override
  State<FriendTrajectoryScreen> createState() => _FriendTrajectoryScreenState();
}

class _FriendTrajectoryScreenState extends State<FriendTrajectoryScreen> {
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    // 确保好友数据已加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendState>().load();
    });
  }

  Future<void> _import() async {
    final file = await FilePicker.pickFile(
      type: FileType.any,
    );
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
      if (!mounted) return;

      // 同名好友已存在 → 询问覆盖更新还是追加
      bool replace = false;
      final state = context.read<FriendState>();
      if (state.hasFriend(friendName)) {
        final choice = await _askReplaceOrAppend(friendName);
        if (choice == null) {
          setState(() => _importing = false);
          return; // 用户取消
        }
        replace = choice;
      }

      final count = await state.importItems(
        friendName: friendName,
        items: items,
        replace: replace,
      );
      _showSnack(replace
          ? '已覆盖更新好友「$friendName」的 $count 条记录'
          : '已导入好友「$friendName」的 $count 条记录');
    } catch (e) {
      if (mounted) _showSnack('导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// 询问同名好友是覆盖更新还是追加，返回 true=覆盖，false=追加，null=取消
  Future<bool?> _askReplaceOrAppend(String friendName) async {
    return showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('好友已存在'),
        content: Text('「$friendName」已有记录，要覆盖更新还是追加到现有记录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('追加'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('覆盖更新'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _deleteFriend(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除好友'),
        content: Text('确定删除好友「$name」及其全部记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<FriendState>().deleteFriend(name);
      if (mounted) _showSnack('已删除好友「$name」');
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendState = context.watch<FriendState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('好友轨迹'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: '导入好友分享',
            onPressed: _importing ? null : _import,
          ),
        ],
      ),
      body: !friendState.loaded
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(friendState),
    );
  }

  Widget _buildBody(FriendState friendState) {
    if (friendState.friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.people_alt_outlined,
                  size: 34, color: AppColors.accent),
            ),
            const SizedBox(height: 16),
            const Text(
              '还没有好友轨迹',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '点击右上角图标，导入好友分享的记录',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _importing ? null : _import,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: Text(_importing ? '导入中...' : '导入好友分享'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final friend in friendState.friends) ...[
          _buildFriendSection(friendState, friend),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildFriendSection(FriendState friendState, Friend friend) {
    final items = friendState.itemsOf(friend.name);
    return Container(
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FriendDetailScreen(friendName: friend.name),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  _initial(friend.name),
                  style: const TextStyle(
                    color: AppColors.accentDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${items.length} 条记录',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') _deleteFriend(friend.name);
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'delete', child: Text('删除好友')),
                ],
                icon: const Icon(Icons.more_horiz, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initial(String name) {
    if (name.isEmpty) return '友';
    return name.substring(0, 1);
  }
}
