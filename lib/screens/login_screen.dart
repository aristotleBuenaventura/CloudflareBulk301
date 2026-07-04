import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_window_sizes.dart';
import '../providers/app_provider.dart';
import '../services/public_ip_service.dart';
import '../widgets/developer_branding.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  bool _obscureToken = true;
  PublicIpInfo? _publicIps;
  bool _loadingIps = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppWindowSizes.applyLoginMinimum();
    });
    _loadPublicIps();
  }

  Future<void> _loadPublicIps() async {
    final ips = await PublicIpService().fetch();
    if (mounted) {
      setState(() {
        _publicIps = ips;
        _loadingIps = false;
      });
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<AppProvider>();
    final success = await provider.login(_tokenController.text);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Login failed.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: SizedBox(
                          width: 480,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 48,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'SEO 301 Redirects',
                                  textAlign: TextAlign.center,
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sign in with your Cloudflare API token to manage bulk redirects.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const _ThemeSelector(),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _tokenController,
                                  obscureText: _obscureToken,
                                  decoration: InputDecoration(
                                    labelText: 'Cloudflare API Token',
                                    hintText: 'Paste your API token here',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureToken
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () {
                                        setState(
                                          () => _obscureToken = !_obscureToken,
                                        );
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'API token is required.';
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                const SizedBox(height: 16),
                                _PublicIpPanel(
                                  ips: _publicIps,
                                  loading: _loadingIps,
                                  onRefresh: _loadPublicIps,
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed:
                                      provider.isLoading ? null : _submit,
                                  child: provider.isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Connect'),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'User tokens create Page Rules. Account (cfat_) tokens use Redirect Rules.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Token is kept in memory only — never saved to disk.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Positioned(
              right: 16,
              bottom: 8,
              child: DeveloperBranding(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Theme',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              label: Text('Light'),
              icon: Icon(Icons.light_mode_outlined, size: 18),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text('Dark'),
              icon: Icon(Icons.dark_mode_outlined, size: 18),
            ),
          ],
          selected: {provider.themeMode},
          onSelectionChanged: (selection) {
            provider.setThemeMode(selection.first);
          },
        ),
      ],
    );
  }
}

class _PublicIpPanel extends StatelessWidget {
  const _PublicIpPanel({
    required this.ips,
    required this.loading,
    required this.onRefresh,
  });

  final PublicIpInfo? ips;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add these IPs to your token allowlist',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              IconButton(
                tooltip: 'Refresh IPs',
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (loading)
            const LinearProgressIndicator()
          else ...[
            _IpRow(label: 'IPv4', value: ips?.ipv4 ?? 'Unavailable'),
            const SizedBox(height: 4),
            _IpRow(label: 'IPv6', value: ips?.ipv6 ?? 'Unavailable'),
          ],
        ],
      ),
    );
  }
}

class _IpRow extends StatelessWidget {
  const _IpRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
