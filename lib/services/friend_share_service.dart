import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/friend.dart';
import '../models/item.dart';

/// 好友轨迹分享服务：把单个/部分/全部记录打包成分享文件，或导入好友分享的文件。
class FriendShareService {
  FriendShareService._();
  static final FriendShareService instance = FriendShareService._();

  static const _shareDir = 'friend_shares';

  /// 导出并分享记录。
  /// [username] 我的用户名（读取自设置），[items] 要分享的记录。
  /// 返回生成的文件路径。
  Future<String> exportAndShare({
    required String username,
    required List<Item> items,
  }) async {
    final data = {
      'app': '观阅轨迹',
      'share_version': 1,
      'username': username,
      'shared_at': DateTime.now().toIso8601String(),
      'items': items.map((e) => e.toMap()).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    final dir = await _dirPath();
    final safeName = username.isEmpty ? '我的' : username;
    final fileName = '观阅轨迹_好友分享_${safeName}_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonStr);

    // 弹出系统分享
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: '${username.isEmpty ? '我' : username} 分享的观阅轨迹记录',
      ),
    );

    return file.path;
  }

  /// 解析好友分享文件，返回（好友名, 记录列表）
  Future<(String, List<FriendItem>)> parseShareFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在');
    }

    final jsonStr = await file.readAsString();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final app = data['app'];
    if (app != '观阅轨迹') {
      throw Exception('不是有效的观阅轨迹分享文件');
    }

    final username = (data['username'] as String?)?.trim() ?? '';
    if (username.isEmpty) {
      throw Exception('分享文件缺少用户名');
    }

    final items = <FriendItem>[];
    final rawItems = data['items'] as List? ?? [];
    for (final m in rawItems) {
      final map = Map<String, dynamic>.from(m as Map);
      items.add(FriendItem.fromMap({
        ...map,
        'friend_name': username,
      }));
    }

    return (username, items);
  }

  /// 分享目录
  Future<Directory> _dirPath() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_shareDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
