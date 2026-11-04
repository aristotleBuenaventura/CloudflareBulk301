import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/csv_parser.dart';
import '../widgets/domain_result_tiles.dart';
import '../widgets/frozen_scroll_viewport.dart';

class BulkRedirectScreen extends StatefulWidget {
  const BulkRedirectScreen({super.key});

  @override
  State<BulkRedirectScreen> createState() => _BulkRedirectScreenState();
}

class _BulkRedirectScreenState extends State<BulkRedirectScreen> {
  final _targetController = TextEditingController();
  final _domainController = TextEditingController();
  final _domains = <String>[];
  var _wildcard = true;
  var _progress = 0;
  var _progressTotal = 0;

  @override
  void dispose() {
    _targetController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  void _addDomain() {
    final parsed = CsvParser.parsePastedDomains(_domainController.text);
    if (parsed.isEmpty) {
      return;
    }

    var added = 0;
    setState(() {
      for (final domain in parsed) {
        if (!_domains.contains(domain)) {
          _domains.add(domain);
          added++;
        }
      }
      _domainController.clear();
    });

    if (!mounted || added == 0) {
      return;
    }
    if (parsed.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $added domain(s).')),
      );
    }
  }

  void _removeDomain(String domain) {
    setState(() => _domains.remove(domain));
  }

  void _clearDomains() {
    setState(() => _domains.clear());
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
      wildcard: _wildcard,
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final results = provider.results;

    return FrozenScrollViewport(
      minWidth: 900,
      minHeight: 560,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final formPanel = Padding(
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
                        : _wildcard
                            ? 'Using User token: Page Rule *domain.com/* → '
                                r'https://target.com/$2'
                            : 'Using User token: Page Rule domain.com/* → '
                                'https://target.com (no path capture)',
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
                const SizedBox(height: 4),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Wildcard'),
                  value: _wildcard,
                  onChanged: provider.isLoading
                      ? null
                      : (value) {
                          setState(() => _wildcard = value ?? true);
                        },
                ),
                const Divider(height: 32),
                Row(
                  children: [
                    Text(
                      'Source domains',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (_domains.isNotEmpty)
                      TextButton.icon(
                        onPressed: provider.isLoading ? null : _clearDomains,
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _domainController,
                        minLines: 1,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          hintText:
                              'olddomain.com — or paste a column from Sheets/Excel',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: provider.isLoading
                            ? null
                            : (_) => _addDomain(),
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
                  'Paste multiple domains from Google Sheets/Excel, or upload a CSV '
                  '(one domain per line, or a column named "domain").',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _domains.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'No domains added yet.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.separated(
                            itemCount: _domains.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
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
          );

          final resultsPanel = Column(
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
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Results will appear here after you apply redirects.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
                      return DomainResultTile(result: results[index]);
                    },
                  ),
                ),
              if (results.isNotEmpty)
                DomainResultSummaryBar(results: results),
            ],
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: formPanel),
              VerticalDivider(
                width: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              Expanded(flex: 3, child: resultsPanel),
            ],
          );
        },
      ),
    );
  }
}
