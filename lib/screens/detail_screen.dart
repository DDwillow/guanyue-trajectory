import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/settings_service.dart';
import '../models/item.dart';
import '../services/friend_share_service.dart';
import '../theme/app_theme.dart';
import 'edit_screen.dart';

/// 作品详情页（只读），点击右上角铅笔进入编辑
class DetailScreen extends StatefulWidget {
  final Item item;
  const DetailScreen({super.key, required this.item});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _sharing = false;

  Item get item => widget.item;

  Future<void> _markWatched(Item current) async {
    await context.read<AppState>().markAsWatched(current);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已标记为「已看」')),
      );
    }
  }

  Future<void> _share() async {
    final app = context.read<AppState>();
    final current = app.items.firstWhere(
      (e) => e.id == item.id,
      orElse: () => item,
    );
    final username = (await SettingsService.instance.getUsername()) ?? '';

    setState(() => _sharing = true);
    try {
      await FriendShareService.instance.exportAndShare(
        username: username,
        items: [current],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final current = app.items.firstWhere(
      (e) => e.id == item.id,
      orElse: () => item,
    );

    final watched = current.status == WatchStatus.watched;
    final hasSummary = current.summary != null && current.summary!.isNotEmpty;
    final hasCreator = current.creator != null && current.creator!.isNotEmpty;
    final hasCast = current.cast != null && current.cast!.isNotEmpty;
    final hasEdition = current.edition != null && current.edition!.isNotEmpty;
    final hasNote = current.note != null && current.note!.isNotEmpty;
    final hasViewMode = current.viewMode != null;
    final hasCompanions = current.companions != null && current.companions!.isNotEmpty;
    final rewatched = current.rewatchCount > 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('详情'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share, color: AppColors.accent),
            tooltip: '分享给好友',
            onPressed: _sharing ? null : _share,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.accent),
            tooltip: '编辑',
            onPressed: () => _openEdit(context, current),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _buildHeaderCard(current, watched),
          // 想看状态：提供「标记已看」按钮
          if (!watched) ...[
            const SizedBox(height: 16),
            _markWatchedButton(current),
          ],
          const SizedBox(height: 16),
          // 简介（主要内容，突出展示）
          if (hasSummary) ...[
            _sectionTitle('简介'),
            _summaryCard(current.summary!),
            const SizedBox(height: 16),
          ],
          // 信息卡片（作者/导演、主演、版本、重看次数、观影方式、共同观影人）
          if (hasCreator || hasCast || hasEdition || rewatched || hasViewMode || hasCompanions) ...[
            _infoCard(current),
            const SizedBox(height: 16),
          ],
          // 标签
          if (current.tags.isNotEmpty) ...[
            _sectionTitle('标签'),
            _tagWrap(current),
            const SizedBox(height: 16),
          ],
          // 我的评价
          if (hasNote) ...[
            _sectionTitle('我的评价'),
            _noteCard(current.note!),
          ],
        ],
      ),
    );
  }

  // ===== 标记已看按钮 =====

  Widget _markWatchedButton(Item item) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _markWatched(item),
        icon: const Icon(Icons.check_circle_outline, size: 20),
        label: const Text('标记为已看'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ===== 头部卡片（标题 + 状态 + 评分 + 时间） =====

  Widget _buildHeaderCard(Item item, bool watched) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 类型图标
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(item.type.icon, style: const TextStyle(fontSize: 34)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _statusBadge(watched),
                        const SizedBox(width: 8),
                        Text(
                          item.type.label,
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (watched) ...[
            const SizedBox(height: 20),
            // 评分
            _ratingBlock(item),
            // 看完时间（单独小框，在评分下方）
            if (item.watchedAt != null) ...[
              const SizedBox(height: 12),
              _watchedAtBox(item),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(bool watched) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: watched ? AppColors.accent : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        watched ? '已看' : '想看',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: watched ? Colors.white : AppColors.accentDark,
        ),
      ),
    );
  }

  Widget _ratingBlock(Item item) {
    final hasRating = item.rating > 0;
    return Row(
      children: [
        if (hasRating) ...[
          Row(
            children: List.generate(5, (i) {
              return Icon(
                i < item.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 26,
                color: AppColors.star,
              );
            }),
          ),
          const SizedBox(width: 10),
          Text(
            '${item.rating}.0',
            style: const TextStyle(
              color: AppColors.star,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ] else
          Row(
            children: [
              Icon(Icons.star_outline_rounded, size: 22, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(
                '未评分',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
      ],
    );
  }

  Widget _watchedAtBox(Item item) {
    final dateStr = DateFormat('yyyy年M月d日').format(item.watchedAt!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_outlined, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(
            '${item.type.watchedAtLabel} $dateStr',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 正文卡片 =====

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

  Widget _summaryCard(String summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        summary,
        style: const TextStyle(
          fontSize: 15,
          height: 1.7,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _infoCard(Item item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (item.creator != null && item.creator!.isNotEmpty)
            _infoRow(Icons.person_outline, item.creatorLabel, item.creator!),
          if (item.cast != null && item.cast!.isNotEmpty)
            _infoRow(Icons.groups_outlined, '主演', item.cast!),
          if (item.edition != null && item.edition!.isNotEmpty)
            _infoRow(Icons.layers_outlined, '版本', item.edition!),
          if (item.rewatchCount > 1)
            _infoRow(Icons.replay_circle_filled_outlined, '重看', '已看 ${item.rewatchCount} 遍'),
          if (item.viewMode != null)
            _infoRow(
              item.viewMode == ViewMode.cinema
                  ? Icons.local_movies_outlined
                  : Icons.home_outlined,
              '观影',
              item.viewMode!.label,
            ),
          if (item.companions != null && item.companions!.isNotEmpty)
            _infoRow(Icons.people_outline, '同看', item.companions!),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagWrap(Item item) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: item.tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '#$tag',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.accentDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _noteCard(String note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      child: Text(
        note,
        style: const TextStyle(
          fontSize: 15,
          height: 1.7,
          color: AppColors.textPrimary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  void _openEdit(BuildContext context, Item item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditScreen(item: item)),
    );
  }
}
