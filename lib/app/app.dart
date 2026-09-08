import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'theme.dart';

class KopaApp extends StatelessWidget {
  const KopaApp({super.key});

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