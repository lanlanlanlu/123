import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 日期格式化辅助类，支持国际化
class DateFormatHelper {
  /// 获取本地化的月日格式
  /// 中文：M月d日 (例如：1月5日)
  /// 英文：MMM d (例如：Jan 5)
  static DateFormat getMonthDayFormat(BuildContext? context) {
    final locale = _getCurrentLocale(context);
    switch (locale) {
      case 'zh':
        return DateFormat('M月d日', 'zh_CN');
      case 'en':
      default:
        return DateFormat('MMM d', 'en_US');
    }
  }
  
  /// 获取本地化的星期格式
  /// 中文：EEEE (例如：星期一)
  /// 英文：EEEE (例如：Monday)
  static DateFormat getWeekdayFormat(BuildContext? context) {
    final locale = _getCurrentLocale(context);
    switch (locale) {
      case 'zh':
        return DateFormat('EEEE', 'zh_CN');
      case 'en':
      default:
        return DateFormat('EEEE', 'en_US');
    }
  }
  
  /// 获取本地化的年份格式
  /// 中文：yyyy年 (例如：2023年)
  /// 英文：yyyy (例如：2023)
  static DateFormat getYearFormat(BuildContext? context) {
    final locale = _getCurrentLocale(context);
    switch (locale) {
      case 'zh':
        return DateFormat('yyyy年', 'zh_CN');
      case 'en':
      default:
        return DateFormat('yyyy', 'en_US');
    }
  }
  
  /// 获取完整的日期时间格式
  /// 中文：yyyy年M月d日 HH:mm:ss
  /// 英文：MMM d, yyyy HH:mm:ss
  static DateFormat getFullDateTimeFormat(BuildContext? context) {
    final locale = _getCurrentLocale(context);
    switch (locale) {
      case 'zh':
        return DateFormat('yyyy年M月d日 HH:mm:ss', 'zh_CN');
      case 'en':
      default:
        return DateFormat('MMM d, yyyy HH:mm:ss', 'en_US');
    }
  }
  
  /// 获取当前语言代码
  /// 如果context为null，尝试从Intl获取默认区域
  /// 如果都不可用，默认使用英语
  static String _getCurrentLocale(BuildContext? context) {
    if (context != null) {
      return Localizations.localeOf(context).languageCode;
    }
    
    // 尝试从Intl获取默认区域
    final defaultLocale = Intl.defaultLocale;
    if (defaultLocale != null && defaultLocale.startsWith('zh')) {
      return 'zh';
    }
    
    // 默认使用英语
    return 'en';
  }
} 