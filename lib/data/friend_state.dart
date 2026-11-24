import 'package:flutter/foundation.dart';

import '../models/friend.dart';
import 'database_helper.dart';

/// 好友轨迹状态管理
class FriendState extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Friend> _friends = [];
  List<FriendItem> _items = [];

  List<Friend> get friends => _friends;
  List<FriendItem> get items => _items;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    _friends = await _db.getFriends();
    _items = await _db.getFriendItems();
    _loaded = true;
    notifyListeners();
  }

  /// 某好友的记录列表
  List<FriendItem> itemsOf(String friendName) {
    return _items.where((e) => e.friendName == friendName).toList();
  }

  /// 导入好友记录（含好友名），返回导入条数。
  /// [replace] 为 true 时覆盖该好友的旧记录，否则追加。
  Future<int> importItems({
    required String friendName,
    required List<FriendItem> items,
    bool replace = false,
  }) async {
    final count = await _db.importFriendItems(
      friendName: friendName,
      items: items,
      replace: replace,
    );
    await load();
    return count;
  }

  /// 某好友是否已存在
  bool hasFriend(String friendName) {
    return _friends.any((e) => e.name == friendName);
  }

  /// 删除好友及其全部记录
  Future<void> deleteFriend(String name) async {
    await _db.deleteFriend(name);
    await load();
  }
}
