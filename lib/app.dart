import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/cabinet/presentation/screens/cabinet_screen.dart';
import 'features/chemist_counter/presentation/screens/chemist_counter_screen.dart';
import 'features/ocr_ingestion/presentation/screens/ocr_scanner_screen.dart';
import 'features/notifications/presentation/screens/adherence_screen.dart';

class MedWiseApp extends StatelessWidget {
  const MedWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MedWiseNavigationShell(),
    );
  }
}

class MedWiseNavigationShell extends StatefulWidget {
  const MedWiseNavigationShell({super.key});

  @override
  State<MedWiseNavigationShell> createState() => _MedWiseNavigationShellState();
}

class _MedWiseNavigationShellState extends State<MedWiseNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    CabinetScreen(),
    ChemistCounterScreen(),
    OcrScannerScreen(),
    AdherenceScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySurface,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services, color: AppColors.primary),
            label: 'Cabinet',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront, color: AppColors.primary),
            label: 'Chemist Buy',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner, color: AppColors.primary),
            label: 'Scan Strip',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm, color: AppColors.primary),
            label: 'Adherence',
          ),
        ],
      ),
    );
  }
}
