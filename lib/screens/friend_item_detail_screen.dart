import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/friend.dart';
import '../models/item.dart';
import '../theme/app_theme.dart';

/// 好友记录的只读详情页（复用 Item 展示逻辑）
class FriendItemDetailScreen extends StatelessWidget {
  final FriendItem item;
  const FriendItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final it = item.toItem();
    final watched = it.status == WatchStatus.watched;
    final hasSummary = it.summary != null && it.summary!.isNotEmpty;
    final hasCreator = it.creator != null && it.creator!.isNotEmpty;
    final hasCast = it.cast != null && it.cast!.isNotEmpty;
    final hasEdition = it.edition != null && it.edition!.isNotEmpty;
    final hasNote = it.note != null && it.note!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('好友记录'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _headerCard(it, watched),
          const SizedBox(height: 16),
          if (hasSummary) ...[
            _sectionTitle('简介'),
            _textCard(it.summary!),
            const SizedBox(height: 16),
          ],
          if (hasCreator || hasCast || hasEdition) ...[
            _infoCard(it),
            const SizedBox(height: 16),
          ],
          if (it.tags.isNotEmpty) ...[
            _sectionTitle('标签'),
            _tagWrap(it),
            const SizedBox(height: 16),
          ],
          if (hasNote) ...[
            _sectionTitle('好友评价'),
            _noteCard(it.note!),
          ],
        ],
      ),
    );
  }

  Widget _headerCard(Item item, bool watched) {
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
            children: [
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
            if (item.rating > 0) _ratingBlock(item.rating),
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

  Widget _ratingBlock(int rating) {
    return Row(
      children: [
        Row(
          children: List.generate(5, (i) {
            return Icon(
              i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 26,
              color: AppColors.star,
            );
          }),
        ),
        const SizedBox(width: 10),
        Text(
          '$rating.0',
          style: const TextStyle(
            color: AppColors.star,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
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

  Widget _textCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
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
}
