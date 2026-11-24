/// 条目类型：书 / 电影 / 动漫 / 电视剧
enum ItemType {
  book,
  movie,
  anime,
  drama;

  String get label {
    switch (this) {
      case ItemType.book:
        return '书';
      case ItemType.movie:
        return '电影';
      case ItemType.anime:
        return '动漫';
      case ItemType.drama:
        return '电视剧';
    }
  }

  String get icon {
    switch (this) {
      case ItemType.book:
        return '📖';
      case ItemType.movie:
        return '🎬';
      case ItemType.anime:
        return '🎐';
      case ItemType.drama:
        return '📺';
    }
  }

  /// 「看完时间」的文案（按类型区分）
  String get watchedAtLabel {
    switch (this) {
      case ItemType.book:
        return '掩卷于';
      case ItemType.movie:
      case ItemType.drama:
        return '落幕于';
      case ItemType.anime:
        return '定格于';
    }
  }
}

/// 观看状态：想看 / 已看
enum WatchStatus {
  wantToWatch,
  watched;

  String get label {
    switch (this) {
      case WatchStatus.wantToWatch:
        return '想看';
      case WatchStatus.watched:
        return '已看';
    }
  }
}

/// 观影方式（仅电影）：居家 / 影院
enum ViewMode {
  home,
  cinema;

  String get label {
    switch (this) {
      case ViewMode.home:
        return '居家观影';
      case ViewMode.cinema:
        return '影院观影';
    }
  }

  String get icon {
    switch (this) {
      case ViewMode.home:
        return '🏠';
      case ViewMode.cinema:
        return '🎬';
    }
  }
}

/// 一个被记录的书/电影/动漫条目
class Item {
  final int? id;
  final String title;
  final ItemType type;
  final WatchStatus status;
  final int rating; // 0-5，0 表示未评分
  final DateTime? watchedAt; // 看完时间
  final String? summary; // 简介（主要内容）
  final String? creator; // 作者（书）/ 导演（电影/动漫/电视剧）
  final String? cast; // 主演（电影/电视剧）
  final String? edition; // 版本（区分同名作品）
  final String? note; // 自己的评价/备注
  final List<String> tags; // 类型/标签
  final int rewatchCount; // 重看次数（已看次数，默认 1 表示首次）
  final ViewMode? viewMode; // 观影方式（仅电影：居家/影院）
  final String? companions; // 共同观影人（仅电影，多人用顿号分隔）
  final DateTime createdAt;

  const Item({
    this.id,
    required this.title,
    required this.type,
    this.status = WatchStatus.wantToWatch,
    this.rating = 0,
    this.watchedAt,
    this.summary,
    this.creator,
    this.cast,
    this.edition,
    this.note,
    this.tags = const [],
    this.rewatchCount = 1,
    this.viewMode,
    this.companions,
    required this.createdAt,
  });

  /// 作者/导演字段的标签（书→作者，其余→导演）
  String get creatorLabel {
    switch (type) {
      case ItemType.book:
        return '作者';
      case ItemType.movie:
      case ItemType.anime:
      case ItemType.drama:
        return '导演';
    }
  }

  Item copyWith({
    int? id,
    String? title,
    ItemType? type,
    WatchStatus? status,
    int? rating,
    DateTime? watchedAt,
    String? summary,
    String? creator,
    String? cast,
    String? edition,
    String? note,
    List<String>? tags,
    int? rewatchCount,
    ViewMode? viewMode,
    String? companions,
    DateTime? createdAt,
  }) {
    return Item(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      watchedAt: watchedAt ?? this.watchedAt,
      summary: summary ?? this.summary,
      creator: creator ?? this.creator,
      cast: cast ?? this.cast,
      edition: edition ?? this.edition,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      rewatchCount: rewatchCount ?? this.rewatchCount,
      viewMode: viewMode ?? this.viewMode,
      companions: companions ?? this.companions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'status': status.name,
      'rating': rating,
      'watched_at': watchedAt?.millisecondsSinceEpoch,
      'summary': summary,
      'creator': creator,
      'cast': cast,
      'edition': edition,
      'note': note,
      'tags': tags.join(','),
      'rewatch_count': rewatchCount,
      'view_mode': viewMode?.name,
      'companions': companions,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    final watchedAtMs = map['watched_at'] as int?;
    final tagsStr = (map['tags'] as String?) ?? '';
    final viewModeStr = map['view_mode'] as String?;
    return Item(
      id: map['id'] as int?,
      title: map['title'] as String,
      type: ItemType.values.byName(map['type'] as String),
      status: WatchStatus.values.byName(map['status'] as String),
      rating: (map['rating'] as int?) ?? 0,
      watchedAt: watchedAtMs == null ? null : DateTime.fromMillisecondsSinceEpoch(watchedAtMs),
      summary: map['summary'] as String?,
      creator: map['creator'] as String?,
      cast: map['cast'] as String?,
      edition: map['edition'] as String?,
      note: map['note'] as String?,
      tags: tagsStr.isEmpty ? const [] : tagsStr.split(','),
      rewatchCount: (map['rewatch_count'] as int?) ?? 1,
      viewMode: viewModeStr == null
          ? null
          : ViewMode.values.firstWhere(
              (e) => e.name == viewModeStr,
              orElse: () => ViewMode.home,
            ),
      companions: map['companions'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
