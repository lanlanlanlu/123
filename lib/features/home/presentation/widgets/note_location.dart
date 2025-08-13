import 'package:flutter/material.dart';

/// 笔记位置组件，用于显示笔记的位置信息
class NoteLocationWidget extends StatelessWidget {
  /// 位置信息
  final String? locationInfo;
  
  const NoteLocationWidget({
    super.key,
    required this.locationInfo,
  });

  @override
  Widget build(BuildContext context) {
    if (locationInfo == null || locationInfo!.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined, 
            size: 12, 
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              locationInfo!,
              style: TextStyle(
                fontSize: 12, 
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
} 