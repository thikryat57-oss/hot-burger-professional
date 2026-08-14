import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../invoices/invoices_screen.dart';
import '../inventory/inventory_screen.dart';
import '../more/more_screen.dart';
import '../sales/sales_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        final screens = [
          const SalesScreen(),
          const InvoicesScreen(),
          const DashboardScreen(),
          const InventoryScreen(),
          const MoreScreen(),
        ];

        final index = appProvider.currentIndex.clamp(0, screens.length - 1);

        return Scaffold(
          body: SafeArea(
            top: false,
            child: IndexedStack(index: index, children: screens),
          ),
          bottomNavigationBar: NavigationBar(
            height: 68,
            elevation: 3,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            indicatorColor: AppTheme.primaryColor.withOpacity(0.14),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: index,
            onDestinationSelected: appProvider.setIndex,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale),
                label: 'المبيعات',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'الفواتير',
              ),
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard),
                label: 'الرئيسية',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'المخزون',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view),
                label: 'المزيد',
              ),
            ],
          ),
          floatingActionButton: index == 2
              ? FloatingActionButton.extended(
                  onPressed: () => appProvider.setIndex(0),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('بيع جديد', style: TextStyle(fontWeight: FontWeight.w800)),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}
