// // lib/features/calendar/presentation/widgets/calendar_header.dart

// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import '../bloc/calendar_bloc.dart';
// import '../bloc/calendar_event.dart';
// import '../bloc/calendar_state.dart';

// class CalendarHeader extends StatelessWidget implements PreferredSizeWidget {
//   final CalendarState state;

//   const CalendarHeader({super.key, required this.state});

//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final selectedDate = state.selectedDate;
//     final now = DateTime.now();

//     // 获取星期几的中文显示
//     final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
//     final weekdayText = weekdays[selectedDate.weekday - 1];

//     return Container(
//       decoration: BoxDecoration(
//         color: Theme.of(context).scaffoldBackgroundColor,
//       ),
//       child: SafeArea(
//         bottom: false,
//         child: Padding(
//           padding: EdgeInsets.symmetric(
//             horizontal: screenWidth < 600 ? 16.0 : 24.0,
//           ),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               // 【最终修改】将日期和年份/星期组合成一个紧密的整体
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   // 左侧：月和日 (使用粗体)
//                   Text(
//                     '${selectedDate.month}月${selectedDate.day}日',
//                     style: const TextStyle(
//                       fontSize: 30, // 确保字体足够大
//                       fontWeight: FontWeight.bold, // 严格按照图片使用粗体
//                     ),
//                   ),
//                   const SizedBox(width: 8), // 微调间距

//                   // 右侧：年份和星期（垂直排列，常规字体）
//                   Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         '${selectedDate.year}',
//                         style: const TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.normal, // 使用常规体
//                         ),
//                       ),
//                       Text(
//                         weekdayText,
//                         style: TextStyle(
//                           fontSize: 14,
//                           color: Colors.grey[700], // 颜色加深一点以匹配图片
//                           fontWeight: FontWeight.normal, // 使用常规体
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//               const Spacer(), // 将“今天”按钮推到最右边
//               TodayButton(today: now),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Size get preferredSize {
//     final window = WidgetsBinding.instance.platformDispatcher.views.first;
//     final double statusBar = window.padding.top / window.devicePixelRatio;
//     return Size.fromHeight(statusBar + 56);
//   }
// }

// class TodayButton extends StatelessWidget {
//   final DateTime today;

//   const TodayButton({super.key, required this.today});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 36,
//       height: 36,
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey[400]!, width: 1),
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius: BorderRadius.circular(6),
//           onTap: () {
//             context.read<CalendarBloc>().add(const CalendarGoToToday());
//           },
//           child: Center(
//             child: Text(
//               '${today.day}',
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }