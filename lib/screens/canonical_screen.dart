import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/domain_result_tiles.dart';
import '../widgets/frozen_scroll_viewport.dart';

class CanonicalScreen extends StatefulWidget {
  const CanonicalScreen({super.key});

  @override
  State<CanonicalScreen> createState() => _CanonicalScreenState();
}

class _CanonicalScreenState extends State<CanonicalScreen> {
  final _leftController = TextEditingController();
  final _rightController = TextEditingController();
  var _progress = 0;
  var _progressTotal = 0;

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  void _clearInputs() {
    setState(() {
      _leftController.clear();
      _rightController.clear();
    });
  }

  Future<void> _applyCanonical() async {
    final left = _leftController.text.trim();
    if (left.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste at least one source URL on the left.'),
        ),
      );
      return;
    }

    final provider = context.read<AppProvider>();
    setState(() {
      _progress = 0;
      _progressTotal = 0;
    });

    try {
      await provider.applyCanonicalRules(
        leftText: _leftController.text,
        rightText: _rightController.text,
        onProgress: (completed, total) {
          if (mounted) {
            setState(() {
              _progress = completed;
              _progressTotal = total;
            });
          }
        },
      );
    } on ArgumentError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Invalid input.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final results = provider.canonicalResults;

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
                    'Uses a Cloudflare Worker to insert or update '
                    '<link rel="canonical"> on HTML responses.\n'
                    'Token needs: Account → Workers Scripts → Edit, '
                    'Zone → Workers Routes → Edit.\n'
                    'Blank right = self. One right line = applies to all left URLs.\n'
                    'A domain home URL (e.g. https://mcw88.bio) sets canonical '
                    'for the whole hostname.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Set canonical',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: provider.isLoading ? null : _clearInputs,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Paste full URLs from a connected Cloudflare domain. '
                  'Left = page URL, right = canonical href.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Source URLs',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: TextField(
                                controller: _leftController,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                decoration: const InputDecoration(
                                  hintText:
                                      'https://old.com/page/\nhttps://old.com/other/',
                                  border: OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Center(
                          child: Icon(
                            Icons.arrow_forward,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Canonical URLs',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: TextField(
                                controller: _rightController,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                decoration: const InputDecoration(
                                  hintText:
                                      'https://new.com/page/\n(or one URL for all / blank = self)',
                                  border: OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: provider.isLoading ? null : _applyCanonical,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    provider.isLoading
                        ? 'Applying… ($_progress / $_progressTotal)'
                        : 'Apply canonical rules',
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
                            : provider.clearCanonicalResults,
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
                        'Results will appear here after you apply canonical rules.',
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
