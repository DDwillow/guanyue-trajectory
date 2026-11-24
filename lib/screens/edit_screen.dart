import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/item.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

class EditScreen extends StatefulWidget {
  final Item? item;
  const EditScreen({super.key, this.item});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _tagCtrl;
  late final TextEditingController _summaryCtrl;
  late final TextEditingController _creatorCtrl;
  late final TextEditingController _castCtrl;
  late final TextEditingController _editionCtrl;
  late final TextEditingController _companionsCtrl;

  late ItemType _type;
  late WatchStatus _status;
  late int _rating;
  late DateTime? _watchedAt;
  late List<String> _tags;
  late int _rewatchCount;
  ViewMode? _viewMode;

  // 当前类型下可选的标签库（预置 + 自定义）
  List<String> _availableTags = [];

  // AI 补全加载状态
  bool _aiLoading = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleCtrl = TextEditingController(text: item?.title ?? '');
    _noteCtrl = TextEditingController(text: item?.note ?? '');
    _tagCtrl = TextEditingController();
    _summaryCtrl = TextEditingController(text: item?.summary ?? '');
    _creatorCtrl = TextEditingController(text: item?.creator ?? '');
    _castCtrl = TextEditingController(text: item?.cast ?? '');
    _editionCtrl = TextEditingController(text: item?.edition ?? '');
    _companionsCtrl = TextEditingController(text: item?.companions ?? '');
    _type = item?.type ?? ItemType.book;
    _status = item?.status ?? WatchStatus.wantToWatch;
    _rating = item?.rating ?? 0;
    _watchedAt = item?.watchedAt;
    _tags = List.from(item?.tags ?? const []);
    _rewatchCount = item?.rewatchCount ?? 1;
    _viewMode = item?.viewMode;
    _loadTags();
  }

  Future<void> _loadTags() async {
    final app = context.read<AppState>();
    final tags = await app.getTags(_type);
    if (mounted) {
      setState(() => _availableTags = tags);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _tagCtrl.dispose();
    _summaryCtrl.dispose();
    _creatorCtrl.dispose();
    _castCtrl.dispose();
    _editionCtrl.dispose();
    _companionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _showSnack('请输入作品名称');
      return;
    }

    final app = context.read<AppState>();
    final now = DateTime.now();

    final summary = _summaryCtrl.text.trim();
    final creator = _creatorCtrl.text.trim();
    final cast = _castCtrl.text.trim();
    final edition = _editionCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    final companions = _companionsCtrl.text.trim();

    // 观影方式/共同观影人仅对电影有意义
    final viewMode = _type == ItemType.movie ? _viewMode : null;
    final companionsVal = _type == ItemType.movie && companions.isNotEmpty
        ? companions
        : null;

    if (_isEdit) {
      final updated = widget.item!.copyWith(
        title: title,
        type: _type,
        status: _status,
        rating: _rating,
        watchedAt: _watchedAt,
        summary: summary.isEmpty ? null : summary,
        creator: creator.isEmpty ? null : creator,
        cast: cast.isEmpty ? null : cast,
        edition: edition.isEmpty ? null : edition,
        note: note.isEmpty ? null : note,
        tags: _tags,
        rewatchCount: _rewatchCount,
        viewMode: viewMode,
        companions: companionsVal,
      );
      await app.updateItem(updated);
    } else {
      final item = Item(
        title: title,
        type: _type,
        status: _status,
        rating: _rating,
        watchedAt: _watchedAt,
        summary: summary.isEmpty ? null : summary,
        creator: creator.isEmpty ? null : creator,
        cast: cast.isEmpty ? null : cast,
        edition: edition.isEmpty ? null : edition,
        note: note.isEmpty ? null : note,
        tags: _tags,
        rewatchCount: _rewatchCount,
        viewMode: viewMode,
        companions: companionsVal,
        createdAt: now,
      );
      await app.addItem(item);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.item == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定删除「${widget.item!.title}」吗？此操作不可恢复。'),
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
      if (!mounted) return;
      await context.read<AppState>().deleteItem(widget.item!.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildAiButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _aiLoading ? null : _aiFill,
        icon: _aiLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome, size: 18),
        label: Text(_aiLoading ? 'AI 补全中...' : 'AI 补全'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _aiFill() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _showSnack('请先填写作品名称');
      return;
    }

    setState(() => _aiLoading = true);
    try {
      final result = await AiService.instance.fillInfo(
        title: title,
        type: _type,
      );
      if (!mounted) return;
      setState(() {
        if (result.summary.isNotEmpty) {
          _summaryCtrl.text = result.summary;
        }
        if (result.creator.isNotEmpty) {
          _creatorCtrl.text = result.creator;
        }
        if (result.cast.isNotEmpty) {
          _castCtrl.text = result.cast;
        }
        if (result.edition.isNotEmpty) {
          _editionCtrl.text = result.edition;
        }
        // 合并 AI 返回的标签（去重）
        for (final tag in result.tags) {
          if (tag.isNotEmpty && !_tags.contains(tag)) {
            _tags.add(tag);
          }
        }
      });
      _showSnack('已补全，请检查并微调');
    } on AiException catch (e) {
      if (mounted) _showSnack(e.message);
    } catch (e) {
      if (mounted) _showSnack('AI 补全失败：$e');
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _addTag() async {
    final tag = _tagCtrl.text.trim();
    if (tag.isEmpty) return;
    if (_tags.contains(tag)) {
      _showSnack('标签已存在');
      return;
    }
    setState(() {
      _tags.add(tag);
      _tagCtrl.clear();
    });
    // 持久化到标签库，下次添加同类型时可直接选
    final app = context.read<AppState>();
    await app.addTag(_type, tag);
    if (mounted) {
      final refreshed = await app.getTags(_type);
      if (mounted) setState(() => _availableTags = refreshed);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _watchedAt ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _watchedAt = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑' : '添加记录'),
        actions: [
          if (_isEdit)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('名称'),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(hintText: '输入作品名称'),
          ),
          const SizedBox(height: 12),
          _buildAiButton(),
          const SizedBox(height: 20),
          _buildSection('类型'),
          _buildTypeSelector(),
          const SizedBox(height: 20),
          _buildSection('状态'),
          _buildStatusSelector(),
          if (_status == WatchStatus.watched) ...[
            const SizedBox(height: 20),
            _buildSection('评分'),
            _buildRatingSelector(),
            const SizedBox(height: 20),
            _buildSection('重看次数'),
            _buildRewatchSelector(),
            const SizedBox(height: 20),
            _buildSection(_type.watchedAtLabel),
            _buildDateField(),
          ],
          const SizedBox(height: 20),
          _buildSection('简介'),
          TextField(
            controller: _summaryCtrl,
            maxLines: 5,
            decoration: const InputDecoration(hintText: '作品的主要内容、剧情梗概等'),
          ),
          const SizedBox(height: 20),
          _buildSection(_type == ItemType.book ? '作者' : '导演'),
          TextField(
            controller: _creatorCtrl,
            decoration: InputDecoration(
              hintText: _type == ItemType.book ? '作者姓名' : '导演姓名',
            ),
          ),
          if (_type == ItemType.movie || _type == ItemType.drama) ...[
            const SizedBox(height: 20),
            _buildSection('主演'),
            TextField(
              controller: _castCtrl,
              decoration: const InputDecoration(hintText: '主要演员，可用逗号分隔'),
            ),
          ],
          const SizedBox(height: 20),
          _buildSection('版本'),
          TextField(
            controller: _editionCtrl,
            decoration: const InputDecoration(
              hintText: '区分同名作品，如某年重拍版、某出版社版',
            ),
          ),
          if (_type == ItemType.movie) ...[
            const SizedBox(height: 20),
            _buildSection('观影方式'),
            _buildViewModeSelector(),
            const SizedBox(height: 20),
            _buildSection('共同观影人'),
            TextField(
              controller: _companionsCtrl,
              decoration: const InputDecoration(hintText: '和谁一起看的，多人用顿号分隔（可选）'),
            ),
          ],
          const SizedBox(height: 20),
          _buildSection('标签'),
          _buildTagEditor(),
          const SizedBox(height: 20),
          _buildSection('我的评价'),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: '写写自己的评价（可选）'),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ItemType.values.map((t) {
        final selected = _type == t;
        return GestureDetector(
          onTap: () {
            setState(() => _type = t);
            _loadTags(); // 切换类型时重新加载对应类型的标签库
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.accentSoft : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.border,
              ),
            ),
            child: Text(
              '${t.icon} ${t.label}',
              style: TextStyle(
                color: selected ? AppColors.accentDark : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusSelector() {
    return Row(
      children: WatchStatus.values.map((s) {
        final selected = _status == s;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _status = s),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accentSoft : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.border,
                  ),
                ),
                child: Text(
                  s.label,
                  style: TextStyle(
                    color: selected ? AppColors.accentDark : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRatingSelector() {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < _rating;
        return GestureDetector(
          onTap: () => setState(() => _rating = filled && _rating == i + 1 ? 0 : i + 1),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              filled ? Icons.star : Icons.star_border,
              size: 36,
              color: AppColors.star,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRewatchSelector() {
    return Row(
      children: [
        IconButton(
          onPressed: _rewatchCount > 1
              ? () => setState(() => _rewatchCount--)
              : null,
          icon: const Icon(Icons.remove_circle_outline, color: AppColors.accent),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$_rewatchCount 遍',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _rewatchCount++),
          icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
        ),
        const SizedBox(width: 8),
        Text(
          _rewatchCount <= 1 ? '首次观看' : '已重看 ${_rewatchCount - 1} 次',
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildViewModeSelector() {
    return Row(
      children: [
        // 居家观影
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _viewMode = ViewMode.home),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _viewMode == ViewMode.home ? AppColors.accentSoft : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _viewMode == ViewMode.home ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Text('🏠 居家观影'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 影院观影
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _viewMode = ViewMode.cinema),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _viewMode == ViewMode.cinema ? AppColors.accentSoft : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _viewMode == ViewMode.cinema ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Text('🎬 影院观影'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: AppColors.textTertiary),
            const SizedBox(width: 10),
            Text(
              _watchedAt == null
                  ? '选择日期'
                  : DateFormat('yyyy-MM-dd').format(_watchedAt!),
              style: TextStyle(
                color: _watchedAt == null
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (_watchedAt != null)
              GestureDetector(
                onTap: () => setState(() => _watchedAt = null),
                child: Icon(Icons.close, size: 18, color: AppColors.textTertiary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagEditor() {
    // 合并：标签库可选标签 + 已选标签（保证已选的即使不在库列表里也展示）
    final available = {..._availableTags, ..._tags}.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 已选标签
        if (_tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              return Chip(
                label: Text('#$tag'),
                onDeleted: () => setState(() => _tags.remove(tag)),
                deleteIconColor: Colors.white70,
                backgroundColor: AppColors.accent,
                labelStyle: const TextStyle(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
        ],
        // 常见标签快捷选择
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: available.map((tag) {
            final selected = _tags.contains(tag);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) {
                  _tags.remove(tag);
                } else {
                  _tags.add(tag);
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accentSoft : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.border,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? AppColors.accentDark : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        // 自定义标签输入
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagCtrl,
                onSubmitted: (_) => _addTag(),
                decoration: const InputDecoration(hintText: '自定义标签'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addTag,
              icon: const Icon(Icons.add_circle, color: AppColors.accent),
            ),
          ],
        ),
      ],
    );
  }
}
