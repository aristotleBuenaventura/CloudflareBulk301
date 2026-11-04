import 'package:flutter/material.dart';

import '../models/domain_result.dart';

class DomainResultTile extends StatelessWidget {
  const DomainResultTile({super.key, required this.result});

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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.domain,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (result.message != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      result.message!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DomainResultSummaryBar extends StatelessWidget {
  const DomainResultSummaryBar({super.key, required this.results});

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
