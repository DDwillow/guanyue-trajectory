import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/item.dart';

/// DeepSeek AI 服务（OpenAI 兼容格式）
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  static const _baseUrl = 'https://api.deepseek.com/chat/completions';
  static const _keyPref = 'deepseek_api_key';
  static const _model = 'deepseek-chat';

  /// 读取已保存的 API Key
  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPref);
  }

  /// 保存 API Key
  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, key);
  }

  /// 是否已配置 Key
  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// AI 补全的作品信息
  Future<AiFillResult> fillInfo({
    required String title,
    required ItemType type,
  }) async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) {
      throw AiException('尚未配置 API Key，请先在设置中填写');
    }

    final typeName = type.label;

    try {
      final resp = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content':
                  '你是一个书影音资料整理助手。根据用户给出的作品名称和类型，补充该作品的标准信息。'
                  '只输出 JSON，不要输出任何其他文字或解释。JSON 字段如下：\n'
                  'creator: 作者（书）或导演（电影/动漫/电视剧）的名字；\n'
                  'cast: 主演名字（仅电影/电视剧需要，其他类型留空字符串），多人用顿号分隔；\n'
                  'summary: 作品简介，80~200字，客观介绍；\n'
                  'edition: 版本信息（若该作品有多个知名版本则注明，如"2024年电影版""人民文学出版社"等，没有则留空字符串）；\n'
                  'tags: 2~4个适合该作品的类型标签数组，用中文短词。',
            },
            {
              'role': 'user',
              'content': '作品名称：$title\n类型：$typeName',
            },
          ],
          'temperature': 0.3,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw AiException('请求失败（HTTP ${resp.statusCode}）');
      }

      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      final content = data['choices'][0]['message']['content'] as String;
      return _parseResult(content);
    } catch (e) {
      if (e is AiException) rethrow;
      throw AiException('请求出错：$e');
    }
  }

  /// AI 分析好友观影/阅读报告（第三人称、系统精炼）
  Future<String> analyzeFriend({
    required String friendName,
    required String myName,
    required List<Item> friendItems,
    required List<Item> myItems,
  }) async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) {
      throw AiException('尚未配置 API Key，请先在设置中填写');
    }

    final friendList = _formatItems(friendItems);
    final myList = _formatItems(myItems);
    final myLabel = myName.trim().isEmpty ? '用户' : myName.trim();

    final prompt = '''
你是一名专业的内容偏好分析师。请基于「$friendName」与「$myLabel」两人的观影/阅读轨迹数据，生成一份第三人称的对比分析报告。

【$friendName 的轨迹】
$friendList

【$myLabel 的轨迹】
$myList

报告要求：
1. 全程使用第三人称客观口吻（称「$friendName」与「$myLabel」），不要出现「你」「我」。
2. 内容系统、精炼、条理清晰，用「**小标题**」分四段，每段 2~4 句，总字数 350 字以内。
3. 四个段落依次为：
   **一、$friendName 的偏好画像**：从其作品类型、题材、风格、评分推断其偏好。
   **二、轨迹重合度**：明确列出两人共同看过的作品，并给出重合度高低判断。
   **三、相近偏好**：概括两人的共同兴趣倾向。
   **四、推荐**：从 $friendName 看过而 $myLabel 未看过的作品中，挑出 $myLabel 最可能喜欢的 2~3 部，各附一句推荐理由。
4. 直接输出报告正文，不要任何前言、结语或额外说明。
''';

    try {
      final resp = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.5,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 60));

      if (resp.statusCode != 200) {
        throw AiException('请求失败（HTTP ${resp.statusCode}）');
      }

      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      return data['choices'][0]['message']['content'] as String;
    } catch (e) {
      if (e is AiException) rethrow;
      throw AiException('请求出错：$e');
    }
  }

  /// 把记录列表格式化成一行一条的文本（含类型、评分、标签）
  String _formatItems(List<Item> items) {
    if (items.isEmpty) return '（暂无记录）';
    return items.map((e) {
      final parts = <String>[
        '《${e.title}》',
        e.type.label,
      ];
      if (e.rating > 0) parts.add('★${e.rating}');
      if (e.tags.isNotEmpty) parts.add('#${e.tags.join(' #')}');
      return parts.join(' · ');
    }).join('\n');
  }

  /// 解析 DeepSeek 返回的 JSON 内容
  AiFillResult _parseResult(String content) {
    // 去除可能的 markdown 代码块包裹
    var jsonStr = content.trim();
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      jsonStr = jsonStr.replaceFirst(RegExp(r'\n?```$'), '');
    }
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;

    List<String> tags = [];
    final rawTags = map['tags'];
    if (rawTags is List) {
      tags = rawTags.map((e) => e.toString()).toList();
    }

    return AiFillResult(
      creator: _str(map['creator']),
      cast: _str(map['cast']),
      summary: _str(map['summary']),
      edition: _str(map['edition']),
      tags: tags,
    );
  }

  String _str(dynamic v) {
    if (v == null) return '';
    return v.toString().trim();
  }
}

/// AI 补全结果
class AiFillResult {
  final String creator;
  final String cast;
  final String summary;
  final String edition;
  final List<String> tags;

  const AiFillResult({
    this.creator = '',
    this.cast = '',
    this.summary = '',
    this.edition = '',
    this.tags = const [],
  });
}

/// AI 相关异常
class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}
