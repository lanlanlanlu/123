/// 笔记工具类，提供笔记处理的公共函数
class NoteUtils {
  /// 从笔记内容中提取标题
  static String getTitle(String content) {
    if (content.isEmpty) return '';
    return content.split('\n').first;
  }
  
  /// 从笔记内容中提取正文
  static String getContentBody(String content) {
    if (!content.contains('\n')) return '';
    return content.substring(content.indexOf('\n') + 1);
  }
  
  /// 从笔记内容中提取标签
  static List<String> extractTags(String content) {
    if (content.isEmpty) return [];
    
    final tagRegExp = RegExp(r"#([\p{L}\p{N}_]+)", unicode: true);
    final matches = tagRegExp.allMatches(content);
    return matches.map((match) => match.group(1)!).toSet().toList();
  }
} 