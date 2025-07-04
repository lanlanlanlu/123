import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 一个可以高亮并处理 #标签 点击的文本组件
class InteractiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Function(String tag) onTagTap;
  final int? maxLines;
  final TextOverflow? overflow;

  const InteractiveText({
    super.key,
    required this.text,
    required this.onTagTap,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 这是用来匹配 #标签 的正则表达式
    final tagRegExp = RegExp(r"#([\p{L}\p{N}_]+)", unicode: true);

    List<TextSpan> textSpans = [];
    text.splitMapJoin(
      tagRegExp,
      onMatch: (Match match) {
        // 这是匹配到的 #标签 部分
        final tagText = match.group(0)!;
        textSpans.add(
          TextSpan(
            text: tagText,
            style: style?.copyWith(color: theme.colorScheme.primary) ??
                TextStyle(color: theme.colorScheme.primary),
            // 为标签添加点击手势
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // 移除 '#' 并触发回调
                onTagTap(tagText.substring(1));
              },
          ),
        );
        return '';
      },
      onNonMatch: (String nonMatch) {
        // 这是普通文本部分
        textSpans.add(TextSpan(text: nonMatch, style: style));
        return '';
      },
    );

    return RichText(
      text: TextSpan(children: textSpans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}