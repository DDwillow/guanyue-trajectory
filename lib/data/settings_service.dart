import 'package:shared_preferences/shared_preferences.dart';

/// 首页副标题优先显示的字段
enum SubtitleField {
  time('时间', '优先显示看完时间'),
  tags('标签', '优先显示类型标签'),
  creator('作者/导演', '优先显示作者或导演'),
  cast('主演', '优先显示主演'),
  edition('版本', '优先显示版本'),
  summary('简介', '优先显示简介');

  final String label;
  final String desc;
  const SubtitleField(this.label, this.desc);

  String get name => toString().split('.').last;
}

/// 应用设置服务
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _subtitleFieldPref = 'subtitle_field';
  static const _usernamePref = 'username';

  /// 读取副标题优先显示字段（默认时间）
  Future<SubtitleField> getSubtitleField() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_subtitleFieldPref);
    if (name == null) return SubtitleField.time;
    return SubtitleField.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SubtitleField.time,
    );
  }

  /// 保存副标题优先显示字段
  Future<void> setSubtitleField(SubtitleField field) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subtitleFieldPref, field.name);
  }

  /// 读取用户名
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernamePref);
  }

  /// 保存用户名
  Future<void> setUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernamePref, username);
  }
}
