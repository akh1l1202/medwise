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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            height: 65,
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primarySurface,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
                label: 'Cabinet',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_pharmacy_outlined),
                selectedIcon: Icon(Icons.local_pharmacy, color: AppColors.primary),
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
        ),
      ),
    );
  }
}
