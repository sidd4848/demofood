import 'package:flutter/material.dart';

import '../theme.dart';
import '../theme_config.dart';
import 'branding.dart';

class AppSidebarShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final PreferredSizeWidget? appBar;
  final Widget child;
  final VoidCallback? onSignOut;

  const AppSidebarShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.appBar,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final config = AppThemeConfig.current;
    return Scaffold(
      appBar: appBar,
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    _SidebarLogo(config: config),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        config.appName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Expanded(
                child: NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    Navigator.pop(context);
                    onDestinationSelected(index);
                  },
                  extended: true,
                  minExtendedWidth: 220,
                  groupAlignment: -0.9,
                  backgroundColor: Theme.of(context).cardColor,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.restaurant_menu_outlined),
                      selectedIcon: Icon(Icons.restaurant_menu_rounded),
                      label: Text('Diet plan'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.auto_awesome_outlined),
                      selectedIcon: Icon(Icons.auto_awesome_rounded),
                      label: Text('Generate diet'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.workspace_premium_outlined),
                      selectedIcon: Icon(Icons.workspace_premium_rounded),
                      label: Text('Upgrade'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.health_and_safety_outlined),
                      selectedIcon: Icon(Icons.health_and_safety_rounded),
                      label: Text('Experts'),
                    ),
                  ],
                ),
              ),
              if (onSignOut != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _SidebarSignOutButton(
                    extended: true,
                    onTap: onSignOut!,
                  ),
                ),
            ],
          ),
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}

class _SidebarLogo extends StatelessWidget {
  final AppThemeConfig config;

  const _SidebarLogo({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: kPrimary.withOpacity(0.12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BrandLogo(asset: config.logoAsset, size: 36),
      ),
    );
  }
}

class _SidebarSignOutButton extends StatelessWidget {
  final bool extended;
  final VoidCallback onTap;

  const _SidebarSignOutButton({
    required this.extended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout_rounded),
            if (extended) ...[
              const SizedBox(width: 8),
              const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
