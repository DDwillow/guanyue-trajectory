import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/settings_service.dart';
import '../models/item.dart';
import '../services/friend_share_service.dart';
import '../theme/app_theme.dart';
import 'detail_screen.dart';
import 'edit_screen.dart';
import 'friend_trajectory_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WatchStatus _status = WatchStatus.watched;
  ItemType? _typeFilter;
  final TextEditingController _searchCtrl = TextEditingController();
  String _keyword = '';
  bool _searching = false;
  SubtitleField _subtitleField = SubtitleField.time;

  // 多选分享模式
  bool _selecting = false;
  final Set<int> _selectedIds = {};
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadSubtitleField();
  }

  Future<void> _loadSubtitleField() async {
    final field = await SettingsService.instance.getSubtitleField();
    if (mounted) {
      setState(() => _subtitleField = field);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: _selecting ? _buildSelectionAppBar() : AppBar(
        title: _searching ? _buildSearchField() : const Text('观阅轨迹'),
        actions: [
          if (!_searching) ...[
            IconButton(
              icon: const Icon(Icons.people_alt_outlined, color: AppColors.textSecondary),
              tooltip: '好友轨迹',
              onPressed: () => _openFriends(context),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
              onPressed: () => _openSettings(context),
            ),
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.textPrimary),
              onPressed: () => setState(() => _searching = true),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchCtrl.clear();
                setState(() {
                  _keyword = '';
                  _searching = false;
                });
              },
            ),
        ],
      ),
      body: !app.loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_keyword.trim().isEmpty) _buildStatusTabs(app),
                Expanded(
                  child: _buildList(app),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEdit(context),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      autofocus: true,
      onChanged: (v) => setState(() => _keyword = v),
      decoration: const InputDecoration(
        hintText: '搜索名称或标签',
        border: InputBorder.none,
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => setState(() {
          _selecting = false;
          _selectedIds.clear();
        }),
      ),
      title: Text('已选 ${_selectedIds.length} 项'),
      actions: [
        TextButton(
          onPressed: _selectAll,
          child: const Text('全选'),
        ),
        TextButton(
          onPressed: _selectedIds.isEmpty || _sharing ? null : _shareSelected,
          child: const Text('分享'),
        ),
      ],
    );
  }

  void _selectAll() {
    final app = context.read<AppState>();
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(app.items.map((e) => e.id!));
    });
  }

  /// 分享选中的记录
  Future<void> _shareSelected() async {
    final app = context.read<AppState>();
    final username = (await SettingsService.instance.getUsername()) ?? '';
    final items = app.items.where((e) => _selectedIds.contains(e.id)).toList();

    setState(() => _sharing = true);
    try {
      await FriendShareService.instance.exportAndShare(
        username: username,
        items: items,
      );
      if (mounted) {
        setState(() {
          _selecting = false;
          _selectedIds.clear();
        });
      }
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

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            _bottomNavItem(null, '全部', Icons.apps),
            ...ItemType.values.map(
              (t) => _bottomNavItem(t, t.label, _iconFor(t)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ItemType t) {
    switch (t) {
      case ItemType.book:
        return Icons.menu_book;
      case ItemType.movie:
        return Icons.movie;
      case ItemType.anime:
        return Icons.auto_awesome;
      case ItemType.drama:
        return Icons.live_tv;
    }
  }

  Widget _bottomNavItem(ItemType? type, String label, IconData icon) {
    final selected = _typeFilter == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _typeFilter = type),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? AppColors.accent : AppColors.textTertiary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? AppColors.accent : AppColors.textTertiary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTabs(AppState app) {
    // 按当前类型筛选计算计数
    final scoped = app.filter(type: _typeFilter);
    final watchedCount = scoped.where((e) => e.status == WatchStatus.watched).length;
    final wantCount = scoped.where((e) => e.status == WatchStatus.wantToWatch).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _statusChip(
            WatchStatus.watched,
            '已看 $watchedCount',
          ),
          _statusChip(
            WatchStatus.wantToWatch,
            '想看 $wantCount',
          ),
        ],
      ),
    );
  }

  Widget _statusChip(WatchStatus status, String label) {
    final selected = _status == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _status = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(AppState app) {
    // 先按类型+关键词搜索，再按状态过滤
    List<Item> items;
    if (_keyword.trim().isNotEmpty) {
      items = app.search(_keyword, type: _typeFilter);
    } else {
      items = app.filter(status: _status, type: _typeFilter);
    }

    if (items.isEmpty) {
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
              child: const Text('🎬', style: TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 16),
            Text(
              _keyword.trim().isNotEmpty ? '没有搜到相关内容' : '还没有记录',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _keyword.trim().isNotEmpty ? '换个关键词试试' : '点右下角 + 添加第一个吧',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _ItemCard(
          item: item,
          subtitleField: _subtitleField,
          selecting: _selecting,
          selected: _selectedIds.contains(item.id),
          onTap: () => _openDetail(context, item),
          onLongPress: () {
            setState(() {
              _selecting = true;
              _selectedIds.add(item.id!);
            });
          },
          onToggleSelect: () {
            setState(() {
              if (_selectedIds.contains(item.id)) {
                _selectedIds.remove(item.id);
                if (_selectedIds.isEmpty) _selecting = false;
              } else {
                _selectedIds.add(item.id!);
              }
            });
          },
        );
      },
    );
  }

  void _openDetail(BuildContext context, Item item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
    );
  }

  void _openFriends(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FriendTrajectoryScreen()),
    );
  }

  void _openSettings(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    // 从设置页返回后刷新副标题显示设置
    if (mounted) _loadSubtitleField();
  }

  void _openEdit(BuildContext context, {Item? item}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditScreen(item: item)),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Item item;
  final SubtitleField subtitleField;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelect;
  final bool selecting;
  final bool selected;

  const _ItemCard({
    required this.item,
    required this.subtitleField,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelect,
    this.selecting = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final watched = item.status == WatchStatus.watched;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        onTap: selecting ? onToggleSelect : onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (selecting) ...[
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selected ? AppColors.accent : AppColors.textTertiary,
                  size: 22,
                ),
                const SizedBox(width: 10),
              ],
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(item.type.icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _buildMeta(watched),
                  ],
                ),
              ),
              _buildRating(watched),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeta(bool watched) {
    final text = _subtitleText(watched);
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 根据设置，生成副标题优先显示的内容
  String _subtitleText(bool watched) {
    // 优先字段
    final primary = _fieldText(subtitleField, watched);
    if (primary.isNotEmpty) {
      // 如果优先字段有内容，再拼一个次要字段（若不同）
      final secondary = _secondaryText(primary, watched);
      return secondary.isNotEmpty ? '$primary · $secondary' : primary;
    }
    // 优先字段为空，回退到任一有内容的字段
    for (final f in SubtitleField.values) {
      if (f == subtitleField) continue;
      final t = _fieldText(f, watched);
      if (t.isNotEmpty) return t;
    }
    return watched ? '未评分' : '待观看';
  }

  /// 次要字段：在优先字段之后补充一个（时间/标签等）
  String _secondaryText(String primary, bool watched) {
    final candidates = SubtitleField.values;
    // 先尝试时间（如果不是当前优先字段），否则标签
    for (final f in candidates) {
      if (f == subtitleField) continue;
      final t = _fieldText(f, watched);
      if (t.isNotEmpty && t != primary) return t;
    }
    return '';
  }

  /// 获取某个字段对应的显示文本
  String _fieldText(SubtitleField field, bool watched) {
    switch (field) {
      case SubtitleField.time:
        if (watched && item.watchedAt != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(item.watchedAt!);
          return '${item.type.watchedAtLabel} $dateStr';
        }
        return '';
      case SubtitleField.tags:
        return item.tags.map((t) => '#$t').join(' ');
      case SubtitleField.creator:
        return item.creator ?? '';
      case SubtitleField.cast:
        return item.cast ?? '';
      case SubtitleField.edition:
        return item.edition ?? '';
      case SubtitleField.summary:
        return item.summary ?? '';
    }
  }

  Widget _buildRating(bool watched) {
    if (!watched || item.rating == 0) {
      return const SizedBox(width: 8);
    }
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        '★ ${item.rating}',
        style: const TextStyle(
          color: AppColors.star,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    );
  }
}
