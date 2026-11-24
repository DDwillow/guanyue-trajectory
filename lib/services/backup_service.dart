import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/database_helper.dart';
import '../models/item.dart';

/// 备份数据（导出/导入到本地 JSON 文件）
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const _backupDir = 'backups';

  /// 导出所有数据到本地文件，返回文件路径
  Future<String> exportAll() async {
    final db = DatabaseHelper.instance;
    final items = await db.getItems();
    final tags = await db.getAllTags();

    final data = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'items': items.map((e) => e.toMap()).toList(),
      'tags': tags,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    final dir = await _backupDirPath();
    final fileName = '观阅轨迹备份_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonStr);

    return file.path;
  }

  /// 从本地文件导入数据，返回导入的记录数
  Future<int> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在');
    }

    final jsonStr = await file.readAsString();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    // 解析 items
    final items = <Item>[];
    final rawItems = data['items'] as List? ?? [];
    for (final m in rawItems) {
      items.add(Item.fromMap(Map<String, dynamic>.from(m as Map)));
    }

    // 解析 tags
    final tags = <String, List<String>>{};
    final rawTags = data['tags'] as Map<String, dynamic>? ?? {};
    rawTags.forEach((key, value) {
      tags[key] = (value as List).map((e) => e.toString()).toList();
    });

    final db = DatabaseHelper.instance;
    await db.importAll(items: items, tags: tags);

    return items.length;
  }

  /// 列出已有的备份文件
  Future<List<File>> listBackups() async {
    final dir = await _backupDirPath();
    final files = dir.listSync().whereType<File>().toList();
    files.sort((a, b) => b.path.compareTo(a.path)); // 新文件在前
    return files;
  }

  /// 备份目录
  Future<Directory> _backupDirPath() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_backupDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
