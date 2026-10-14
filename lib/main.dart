import 'package:flutter/material.dart';

import 'screens/report_list.dart';
import 'widgets/logo_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReportesApp());
}

class ReportesApp extends StatelessWidget {
  const ReportesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reportes J&H',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          primary: kAccent,
          brightness: Brightness.light,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: const ReportListScreen(),
    );
  }
}
