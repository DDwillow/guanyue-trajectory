import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/friend.dart';
import '../models/item.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'guanyue.db';
  static const _dbVersion = 7;
  static const _table = 'items';
  static const _tagTable = 'tag_library';
  static const _friendTable = 'friends';
  static const _friendItemTable = 'friend_items';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            type TEXT NOT NULL,
            status TEXT NOT NULL,
            rating INTEGER NOT NULL DEFAULT 0,
            watched_at INTEGER,
            summary TEXT,
            creator TEXT,
            cast TEXT,
            edition TEXT,
            note TEXT,
            tags TEXT,
            rewatch_count INTEGER NOT NULL DEFAULT 1,
            view_mode TEXT,
            companions TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE $_tagTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            UNIQUE(type, name)
          )
        ''');
        await _createFriendTables(db);
        await _seedDefaultTags(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE $_tagTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type TEXT NOT NULL,
              name TEXT NOT NULL,
              UNIQUE(type, name)
            )
          ''');
          await _seedDefaultTags(db);
        }
        if (oldVersion < 3) {
          // 替换默认标签：删除旧预置标签，写入新预置标签
          // （自定义标签不在旧预置列表里，会被保留）
          for (final old in _oldDefaultTags.entries) {
            await db.delete(
              _tagTable,
              where: 'type = ? AND name IN (${List.filled(old.value.length, '?').join(',')})',
              whereArgs: [old.key, ...old.value],
            );
          }
          await _seedDefaultTags(db);
        }
        if (oldVersion < 4) {
          // 新增「电视剧」类型，补充其默认标签
          await _seedDefaultTags(db);
        }
        if (oldVersion < 5) {
          // 新增简介/作者导演/主演/版本字段
          await db.execute('ALTER TABLE $_table ADD COLUMN summary TEXT');
          await db.execute('ALTER TABLE $_table ADD COLUMN creator TEXT');
          await db.execute('ALTER TABLE $_table ADD COLUMN cast TEXT');
          await db.execute('ALTER TABLE $_table ADD COLUMN edition TEXT');
        }
        if (oldVersion < 6) {
          await _createFriendTables(db);
        }
        if (oldVersion < 7) {
          // 新增重看次数、观影方式、共同观影人字段
          await db.execute('ALTER TABLE $_table ADD COLUMN rewatch_count INTEGER NOT NULL DEFAULT 1');
          await db.execute('ALTER TABLE $_table ADD COLUMN view_mode TEXT');
          await db.execute('ALTER TABLE $_table ADD COLUMN companions TEXT');
        }
      },
    );
  }

  Future<void> _createFriendTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_friendTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_friendItemTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        friend_name TEXT NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        rating INTEGER NOT NULL DEFAULT 0,
        watched_at INTEGER,
        summary TEXT,
        creator TEXT,
        cast TEXT,
        edition TEXT,
        note TEXT,
        tags TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  /// 新预置标签（v4）
  static const Map<String, List<String>> _defaultTags = {
    'book': ['言情', '玄幻', '奇幻', '科幻', '悬疑', '推理', '恐怖', '历史', '武侠', '仙侠', '都市', '青春', '军事', '传记', '社科', '科普', '商业', '自助', '童书', '漫画'],
    'anime': ['热血', '恋爱', '奇幻', '科幻', '机甲', '悬疑', '推理', '恐怖', '治愈', '日常', '搞笑', '运动', '校园', '后宫', '耽美', '百合', '战争', '青年', '少女', '少年'],
    'movie': ['动作', '喜剧', '爱情', '科幻', '奇幻', '恐怖', '悬疑', '推理', '犯罪', '剧情', '战争', '历史', '传记', '动画', '纪录', '公路', '歌舞', '武侠', '灾难', '惊悚'],
    'drama': ['剧情', '爱情', '都市', '家庭', '悬疑', '推理', '犯罪', '古装', '历史', '武侠', '仙侠', '玄幻', '奇幻', '科幻', '战争', '谍战', '喜剧', '青春', '职场', '传记', '纪录', '动画', '短剧', '季播'],
  };

  /// 旧预置标签（v2），用于升级时清理
  static const Map<String, List<String>> _oldDefaultTags = {
    'book': ['小说', '科幻', '悬疑', '历史', '传记', '散文', '心理', '工具书', '治愈', '推理'],
    'movie': ['科幻', '悬疑', '动作', '喜剧', '爱情', '动画', '恐怖', '剧情', '纪录片', '治愈'],
    'anime': ['热血', '治愈', '搞笑', '恋爱', '科幻', '奇幻', '悬疑', '日常', '运动', '致郁'],
  };

  /// 预置各类型的常见标签
  Future<void> _seedDefaultTags(Database db) async {
    final batch = db.batch();
    _defaultTags.forEach((type, names) {
      for (final name in names) {
        batch.insert(
          _tagTable,
          {'type': type, 'name': name},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    await batch.commit(noResult: true);
  }

  // ===== 条目 =====

  Future<List<Item>> getItems() async {
    final db = await database;
    final maps = await db.query(_table, orderBy: 'created_at DESC');
    return maps.map(Item.fromMap).toList();
  }

  Future<int> insertItem(Item item) async {
    final db = await database;
    return db.insert(_table, item.toMap()..remove('id'));
  }

  Future<int> updateItem(Item item) async {
    final db = await database;
    return db.update(_table, item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  // ===== 标签库 =====

  Future<List<String>> getTagsForType(ItemType type) async {
    final db = await database;
    final maps = await db.query(
      _tagTable,
      where: 'type = ?',
      whereArgs: [type.name],
      orderBy: 'id ASC',
    );
    return maps.map((m) => m['name'] as String).toList();
  }

  /// 保存自定义标签（若已存在则忽略），返回是否新增
  Future<bool> addTag(ItemType type, String name) async {
    final db = await database;
    final existing = await db.query(
      _tagTable,
      where: 'type = ? AND name = ?',
      whereArgs: [type.name, name],
    );
    if (existing.isNotEmpty) return false;
    await db.insert(_tagTable, {'type': type.name, 'name': name});
    return true;
  }

  // ===== 备份 / 导入 =====

  /// 获取所有标签（type -> 标签名列表），用于导出
  Future<Map<String, List<String>>> getAllTags() async {
    final db = await database;
    final maps = await db.query(_tagTable, orderBy: 'id ASC');
    final result = <String, List<String>>{};
    for (final m in maps) {
      final type = m['type'] as String;
      final name = m['name'] as String;
      result.putIfAbsent(type, () => []).add(name);
    }
    return result;
  }

  /// 清空所有记录并导入备份数据
  Future<void> importAll({
    required List<Item> items,
    required Map<String, List<String>> tags,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // 清空现有数据
      await txn.delete(_table);
      await txn.delete(_tagTable);
      // 导入记录
      for (final item in items) {
        await txn.insert(_table, item.toMap()..remove('id'));
      }
      // 导入标签库
      for (final entry in tags.entries) {
        for (final name in entry.value) {
          await txn.insert(
            _tagTable,
            {'type': entry.key, 'name': name},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
      // 重新预置默认标签（确保基础标签不丢失）
    });
    await _seedDefaultTags(db);
  }

  // ===== 好友轨迹 =====

  /// 获取所有好友（按创建时间排序）
  Future<List<Friend>> getFriends() async {
    final db = await database;
    final maps = await db.query(_friendTable, orderBy: 'created_at ASC');
    return maps.map(Friend.fromMap).toList();
  }

  /// 获取所有好友记录
  Future<List<FriendItem>> getFriendItems() async {
    final db = await database;
    final maps = await db.query(_friendItemTable, orderBy: 'created_at DESC');
    return maps.map(FriendItem.fromMap).toList();
  }

  /// 获取某个好友的所有记录
  Future<List<FriendItem>> getFriendItemsByName(String name) async {
    final db = await database;
    final maps = await db.query(
      _friendItemTable,
      where: 'friend_name = ?',
      whereArgs: [name],
      orderBy: 'created_at DESC',
    );
    return maps.map(FriendItem.fromMap).toList();
  }

  /// 新增好友（若同名已存在则返回已有好友），返回好友名
  Future<String> ensureFriend(String name) async {
    final db = await database;
    final existing = await db.query(
      _friendTable,
      where: 'name = ?',
      whereArgs: [name],
    );
    if (existing.isEmpty) {
      await db.insert(_friendTable, {
        'name': name,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
    return name;
  }

  /// 导入一批好友记录（属于同一好友），返回导入条数。
  /// [replace] 为 true 时，先清空该好友的旧记录再插入（覆盖更新）；否则追加。
  Future<int> importFriendItems({
    required String friendName,
    required List<FriendItem> items,
    bool replace = false,
  }) async {
    final db = await database;
    await ensureFriend(friendName);
    var count = 0;
    await db.transaction((txn) async {
      if (replace) {
        await txn.delete(
          _friendItemTable,
          where: 'friend_name = ?',
          whereArgs: [friendName],
        );
      }
      for (final item in items) {
        await txn.insert(_friendItemTable, item.toMap()..remove('id'));
        count++;
      }
    });
    return count;
  }

  /// 删除一个好友及其全部记录
  Future<void> deleteFriend(String name) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_friendItemTable, where: 'friend_name = ?', whereArgs: [name]);
      await txn.delete(_friendTable, where: 'name = ?', whereArgs: [name]);
    });
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
