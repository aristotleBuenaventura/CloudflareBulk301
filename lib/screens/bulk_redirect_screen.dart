import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/domain_result.dart';
import '../providers/app_provider.dart';
import '../services/csv_parser.dart';

class BulkRedirectScreen extends StatefulWidget {
  const BulkRedirectScreen({super.key});

  @override
  State<BulkRedirectScreen> createState() => _BulkRedirectScreenState();
}

class _BulkRedirectScreenState extends State<BulkRedirectScreen> {
  final _targetController = TextEditingController();
  final _domainController = TextEditingController();
  final _domains = <String>[];
  var _preservePath = true;
  var _preserveQueryString = true;
  var _progress = 0;
  var _progressTotal = 0;

  @override
  void dispose() {
    _targetController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  void _addDomain() {
    final domain = _domainController.text.trim();
    if (domain.isEmpty) {
      return;
    }
    setState(() {
      if (!_domains.contains(domain)) {
        _domains.add(domain);
      }
      _domainController.clear();
    });
  }

  void _removeDomain(String domain) {
    setState(() => _domains.remove(domain));
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final content = file.bytes != null
        ? String.fromCharCodes(file.bytes!)
        : await File(file.path!).readAsString();

    final imported = CsvParser.parseDomains(content);
    if (imported.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No domains found in the file.')),
        );
      }
      return;
    }

    setState(() {
      for (final domain in imported) {
        if (!_domains.contains(domain)) {
          _domains.add(domain);
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${imported.length} domain(s).')),
      );
    }
  }

  Future<void> _applyRedirects() async {
    final target = _targetController.text.trim();
    if (target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a target URL first.')),
      );
      return;
    }

    if (_domains.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one source domain.')),
      );
      return;
    }

    final provider = context.read<AppProvider>();
    setState(() {
      _progress = 0;
      _progressTotal = _domains.length;
    });

    await provider.applyBulkRedirects(
      domains: _domains,
      targetUrl: target,
      preservePath: _preservePath,
      preserveQueryString: _preserveQueryString,
      onProgress: (completed, total) {
        if (mounted) {
          setState(() {
            _progress = completed;
            _progressTotal = total;
          });
        }
      },
    );
  }

  void _logout() {
    context.read<AppProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final results = provider.results;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk 301 Redirects'),
        actions: [
          if (provider.accountEmail != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  provider.accountEmail!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: provider.isLoading ? null : _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      provider.isAccountToken
                          ? '⚠️ cfat_ token: rules go to Rules → Overview → Redirect Rules.\n'
                              'Existing 301 rules will be overwritten.'
                          : 'Using User token: creates/updates Page Rules like *domain.com/* → '
                              r'https://target.com/$2. Works even if zone is pending — '
                              'redirect activates once nameservers are valid.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Target domain',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _targetController,
                    decoration: const InputDecoration(
                      hintText: 'https://newdomain.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Preserve path'),
                    subtitle: const Text(
                      'e.g. old.com/page → newdomain.com/page',
                    ),
                    value: _preservePath,
                    onChanged: provider.isLoading
                        ? null
                        : (value) => setState(() => _preservePath = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Preserve query string'),
                    subtitle: const Text('Keep ?utm=... and other parameters'),
                    value: _preserveQueryString,
                    onChanged: provider.isLoading
                        ? null
                        : (value) =>
                            setState(() => _preserveQueryString = value),
                  ),
                  const Divider(height: 32),
                  Text(
                    'Source domains',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _domainController,
                          decoration: const InputDecoration(
                            hintText: 'olddomain.com',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _addDomain(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: provider.isLoading ? null : _addDomain,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: provider.isLoading ? null : _importCsv,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload CSV'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CSV: one domain per line, or a column named "domain".',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_domains.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'No domains added yet.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _domains.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final domain = _domains[index];
                          return ListTile(
                            dense: true,
                            title: Text(domain),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: provider.isLoading
                                  ? null
                                  : () => _removeDomain(domain),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: provider.isLoading ? null : _applyRedirects,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      provider.isLoading
                          ? 'Applying… ($_progress / $_progressTotal)'
                          : 'Apply 301 redirects',
                    ),
                  ),
                  if (provider.isLoading && _progressTotal > 0) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _progress / _progressTotal,
                    ),
                  ],
                ],
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            color: theme.colorScheme.outlineVariant,
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Row(
                    children: [
                      Text(
                        'Results',
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      if (results.isNotEmpty)
                        TextButton(
                          onPressed: provider.isLoading
                              ? null
                              : provider.clearResults,
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                ),
                if (results.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'Results will appear here after you apply redirects.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _ResultTile(result: results[index]);
                      },
                    ),
                  ),
                if (results.isNotEmpty) _SummaryBar(results: results),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final DomainResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, label) = switch (result.status) {
      DomainResultStatus.pending => (
          Icons.hourglass_empty,
          theme.colorScheme.outline,
          'Pending',
        ),
      DomainResultStatus.success => (
          Icons.check_circle,
          Colors.green,
          'Success',
        ),
      DomainResultStatus.skipped => (
          Icons.info_outline,
          Colors.orange,
          'Skipped',
        ),
      DomainResultStatus.failed => (
          Icons.error_outline,
          theme.colorScheme.error,
          'Failed',
        ),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(result.domain),
        subtitle: Text(result.message ?? label),
        trailing: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.results});

  final List<DomainResult> results;

  @override
  Widget build(BuildContext context) {
    final success = results
        .where((r) => r.status == DomainResultStatus.success)
        .length;
    final skipped = results
        .where((r) => r.status == DomainResultStatus.skipped)
        .length;
    final failed =
        results.where((r) => r.status == DomainResultStatus.failed).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Text(
        '$success created · $skipped skipped · $failed failed · ${results.length} total',
        textAlign: TextAlign.center,
      ),
    );
  }
}
