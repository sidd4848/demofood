import 'package:flutter/material.dart';

import '../theme.dart';
import '../theme_config.dart';
import 'branding.dart';

class AppSidebarShell extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final PreferredSizeWidget? appBar;
  final Widget child;
  final VoidCallback? onSignOut;
  final bool initialExtended;

  const AppSidebarShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.appBar,
    this.onSignOut,
    this.initialExtended = false,
  });

  @override
  State<AppSidebarShell> createState() => _AppSidebarShellState();
}

class _AppSidebarShellState extends State<AppSidebarShell> {
  late bool _isExtended;

  @override
  void initState() {
    super.initState();
    _isExtended = widget.initialExtended;
  }

  @override
  Widget build(BuildContext context) {
    final config = AppThemeConfig.current;
    return Scaffold(
      appBar: widget.appBar,
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: widget.onDestinationSelected,
              extended: _isExtended,
              labelType: _isExtended ? null : NavigationRailLabelType.selected,
              minExtendedWidth: 220,
              groupAlignment: -0.9,
              backgroundColor: Theme.of(context).cardColor,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: _isExtended ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: _isExtended ? 'Collapse sidebar' : 'Expand sidebar',
                      icon: Icon(_isExtended ? Icons.chevron_left_rounded : Icons.chevron_right_rounded),
                      onPressed: () {
                        setState(() {
                          _isExtended = !_isExtended;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_isExtended)
                      Row(
                        children: [
                          _SidebarLogo(config: config),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 140,
                            child: Text(
                              config.appName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      _SidebarLogo(config: config),
                  ],
                ),
              ),
              trailing: widget.onSignOut == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _SidebarSignOutButton(
                        extended: _isExtended,
                        onTap: widget.onSignOut!,
                      ),
                    ),
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
            const VerticalDivider(width: 1),
            Expanded(child: widget.child),
          ],
        ),
      ),
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
