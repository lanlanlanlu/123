import 'package:intl/intl.dart';

extension DateFormatting on DateTime {
  /// 格式化日期为 "yyyy-MM-dd" 格式
  String toYYMMDD() {
    return DateFormat('yyyy-MM-dd').format(this);
  }
}