import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_window_sizes.dart';
import '../providers/app_provider.dart';
import '../widgets/developer_branding.dart';
import 'bulk_redirect_screen.dart';
import 'canonical_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppWindowSizes.applyBulkMinimum();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _logout() {
    context.read<AppProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SEO 301 Redirects'),
        actions: [
          if (provider.accountEmail != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    provider.accountEmail!,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: provider.isLoading ? null : _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.alt_route),
              text: '301 Redirects',
            ),
            Tab(
              icon: Icon(Icons.link),
              text: 'Canonical',
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: const [
              BulkRedirectScreen(),
              CanonicalScreen(),
            ],
          ),
          const Positioned(
            right: 16,
            bottom: 8,
            child: DeveloperBranding(),
          ),
        ],
      ),
    );
  }
}
