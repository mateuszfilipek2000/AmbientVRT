import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'preview_fixtures.dart';

@Preview(
  group: 'Basics',
  name: 'Plain card',
  theme: previewTheme,
)
Widget plainMessagePreview() => const PlainMessageCard();

class FixturePreviewFactory {
  @Preview(
    group: 'Fixtures',
    name: 'Injected fixture',
    wrapper: fixturePreviewHarness,
    theme: previewTheme,
  )
  static Widget build() => const FixtureDrivenCard();
}

@LightDarkProductPreviews()
Widget productStatusPreview() => const ProductStatusTile();

class SizedSummaryCard extends StatelessWidget {
  @Preview(
    group: 'Layout',
    name: 'Sized summary',
    size: Size(320, 180),
    theme: previewTheme,
    localizations: polishPreviewLocalizations,
    textScaleFactor: 1.15,
  )
  const SizedSummaryCard.preview({super.key});

  const SizedSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Regional digest',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Locale: ${locale.toLanguageTag()}'),
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(value: 0.72),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.insights_rounded,
                size: 42,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlainMessageCard extends StatelessWidget {
  const PlainMessageCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: <Widget>[
            Text(
              'AmbientVRT',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text(
              'Flutter widget previews can be captured into deterministic PNG baselines.',
            ),
          ],
        ),
      ),
    );
  }
}

class FixtureDrivenCard extends StatelessWidget {
  const FixtureDrivenCard({super.key});

  @override
  Widget build(BuildContext context) {
    final fixture = PreviewFixtureScope.of(context);
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              child: Text(fixture.pendingAlerts.toString()),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: <Widget>[
                  Text(
                    fixture.customerName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('${fixture.pendingAlerts} alerts waiting for review'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductStatusTile extends StatelessWidget {
  const ProductStatusTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: <Widget>[
            Text(
              'Catalog sync',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '91% of suppliers refreshed in the last 24 hours.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            LinearProgressIndicator(
              value: 0.91,
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
            ),
          ],
        ),
      ),
    );
  }
}
