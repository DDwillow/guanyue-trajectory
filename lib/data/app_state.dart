import 'package:flutter/foundation.dart';

import '../models/item.dart';
import 'database_helper.dart';

class AppState extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Item> _items = [];
  List<Item> get items => _items;

  bool _loaded = false;
  bool get loaded => _loaded;

  // 标签库缓存：type.name -> List<String>
  final Map<String, List<String>> _tagLibrary = {};

  Future<void> load() async {
    _items = await _db.getItems();
    _loaded = true;
    notifyListeners();
  }

  Future<void> addItem(Item item) async {
    final id = await _db.insertItem(item);
    _items.insert(0, item.copyWith(id: id));
    notifyListeners();
  }

  Future<void> updateItem(Item item) async {
    await _db.updateItem(item);
    final idx = _items.indexWhere((e) => e.id == item.id);
    if (idx != -1) _items[idx] = item;
    notifyListeners();
  }

  Future<void> deleteItem(int id) async {
    await _db.deleteItem(id);
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// 把「想看」标记为「已看」（详情页一键操作）
  Future<void> markAsWatched(Item item) async {
    final updated = item.copyWith(
      status: WatchStatus.watched,
      watchedAt: item.watchedAt ?? DateTime.now(),
    );
    await updateItem(updated);
  }

  List<Item> filter({
    WatchStatus? status,
    ItemType? type,
  }) {
    return _items.where((e) {
      if (status != null && e.status != status) return false;
      if (type != null && e.type != type) return false;
      return true;
    }).toList();
  }

  /// 搜索：按名称或标签匹配；type 为 null 表示全局搜索
  List<Item> search(String keyword, {ItemType? type}) {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) {
      return type == null ? List.of(_items) : filter(type: type);
    }
    return _items.where((e) {
      if (type != null && e.type != type) return false;
      final titleMatch = e.title.toLowerCase().contains(kw);
      final tagMatch = e.tags.any((t) => t.toLowerCase().contains(kw));
      return titleMatch || tagMatch;
    }).toList();
  }

  /// 获取某类型下可选的标签（含预置 + 自定义），带缓存
  Future<List<String>> getTags(ItemType type) async {
    final key = type.name;
    if (_tagLibrary.containsKey(key)) return _tagLibrary[key]!;
    final tags = await _db.getTagsForType(type);
    _tagLibrary[key] = tags;
    return tags;
  }

  /// 添加自定义标签到标签库（持久化），返回是否新增
  Future<bool> addTag(ItemType type, String name) async {
    final added = await _db.addTag(type, name);
    if (added) {
      final key = type.name;
      final list = _tagLibrary[key];
      if (list != null) {
        list.add(name);
      } else {
        _tagLibrary[key] = await _db.getTagsForType(type);
      }
      notifyListeners();
    }
    return added;
  }

  int get watchedCount =>
      _items.where((e) => e.status == WatchStatus.watched).length;
  int get wantCount =>
      _items.where((e) => e.status == WatchStatus.wantToWatch).length;
}
