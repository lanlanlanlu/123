import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 设置页面内容，确保不包含Scaffold
    return const Center(
      child: Text(
        '设置页面',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}