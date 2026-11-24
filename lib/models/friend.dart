/// 好友及好友轨迹记录模型

import 'item.dart';

/// 一个好友：按好友名（用户名）归类，每个好友一个栏目
class Friend {
  final String name; // 好友名（对方设置的用户名）
  final DateTime createdAt;

  const Friend({required this.name, required this.createdAt});

  Friend copyWith({String? name, DateTime? createdAt}) {
    return Friend(
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Friend.fromMap(Map<String, dynamic> map) {
    return Friend(
      name: map['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

/// 好友轨迹里的一条记录（来自好友分享，只读展示）
class FriendItem {
  final int? id;
  final String friendName; // 所属好友名
  final String title;
  final String type; // ItemType.name
  final String status; // WatchStatus.name
  final int rating;
  final DateTime? watchedAt;
  final String? summary;
  final String? creator;
  final String? cast;
  final String? edition;
  final String? note;
  final List<String> tags;
  final DateTime createdAt;

  const FriendItem({
    this.id,
    required this.friendName,
    required this.title,
    required this.type,
    required this.status,
    this.rating = 0,
    this.watchedAt,
    this.summary,
    this.creator,
    this.cast,
    this.edition,
    this.note,
    this.tags = const [],
    required this.createdAt,
  });

  FriendItem copyWith({int? id}) {
    return FriendItem(
      id: id ?? this.id,
      friendName: friendName,
      title: title,
      type: type,
      status: status,
      rating: rating,
      watchedAt: watchedAt,
      summary: summary,
      creator: creator,
      cast: cast,
      edition: edition,
      note: note,
      tags: tags,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'friend_name': friendName,
      'title': title,
      'type': type,
      'status': status,
      'rating': rating,
      'watched_at': watchedAt?.millisecondsSinceEpoch,
      'summary': summary,
      'creator': creator,
      'cast': cast,
      'edition': edition,
      'note': note,
      'tags': tags.join(','),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory FriendItem.fromMap(Map<String, dynamic> map) {
    final watchedAtMs = map['watched_at'] as int?;
    final tags = _parseTags(map['tags']);
    return FriendItem(
      id: map['id'] as int?,
      friendName: map['friend_name'] as String,
      title: map['title'] as String,
      type: map['type'] as String,
      status: map['status'] as String,
      rating: (map['rating'] as int?) ?? 0,
      watchedAt: watchedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(watchedAtMs),
      summary: map['summary'] as String?,
      creator: map['creator'] as String?,
      cast: map['cast'] as String?,
      edition: map['edition'] as String?,
      note: map['note'] as String?,
      tags: tags,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// 兼容 tags 的两种格式：逗号分隔字符串 或 JSON 数组
  static List<String> _parseTags(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (raw is String) {
      if (raw.isEmpty) return const [];
      return raw.split(',').where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList();
    }
    return const [];
  }

  /// 转换为标准 Item（用于复用详情页展示），类型/状态字符串安全解析
  Item toItem() {
    return Item(
      id: id,
      title: title,
      type: _safeType(type),
      status: _safeStatus(status),
      rating: rating,
      watchedAt: watchedAt,
      summary: summary,
      creator: creator,
      cast: cast,
      edition: edition,
      note: note,
      tags: tags,
      createdAt: createdAt,
    );
  }

  static ItemType _safeType(String name) {
    return ItemType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ItemType.movie,
    );
  }

  static WatchStatus _safeStatus(String name) {
    return WatchStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => WatchStatus.watched,
    );
  }
}
