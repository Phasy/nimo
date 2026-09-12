import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'theme.dart';

class NomiApp extends StatelessWidget {
  const NomiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nimo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}