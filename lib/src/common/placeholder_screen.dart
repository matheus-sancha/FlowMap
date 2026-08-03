import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// A destination that exists in the shell but whose milestone has not landed.
///
/// Present from M1 so the navigation shape is real from the first build — an
/// empty rail slot is a worse answer to "where will projects live" than a
/// labelled one that says not yet.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).comingSoon,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
