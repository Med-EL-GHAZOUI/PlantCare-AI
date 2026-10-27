import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../data/prediction_api.dart';
import '../l10n/app_localizations.dart';
import 'localized_text.dart';

String _percent(BuildContext context, double value) {
  final locale = Localizations.localeOf(context).toString();
  return NumberFormat.percentPattern(locale).format(value);
}

/// Texte de prudence affiché avec tout résultat.
class DisclaimerCard extends StatelessWidget {
  const DisclaimerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('disclaimer'),
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.info_outline, color: scheme.primary),
              const SizedBox(width: 8),
              Text(l10n.limitsTitle, style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 8),
            Text(l10n.disclaimer),
            const SizedBox(height: 8),
            Text(l10n.limitsBody, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class PredictionView extends StatelessWidget {
  const PredictionView({super.key, required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    return prediction.isUncertain
        ? _UncertainCard(key: const Key('uncertain_card'))
        : _AvailableCard(key: const Key('result_card'), prediction: prediction);
  }
}

class _UncertainCard extends StatelessWidget {
  const _UncertainCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.help_outline, color: scheme.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.uncertainTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onTertiaryContainer),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(l10n.uncertainBody, style: TextStyle(color: scheme.onTertiaryContainer)),
          ],
        ),
      ),
    );
  }
}

class _AvailableCard extends StatelessWidget {
  const _AvailableCard({super.key, required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final predicted = prediction.predictedClass!;
    final others = prediction.topScores(3).where((entry) => entry.key != predicted).take(2).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.resultTitle, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              localizedClassName(l10n, predicted),
              key: const Key('predicted_class'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(l10n.modelScore(_percent(context, prediction.confidence)), key: const Key('model_score')),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: prediction.confidence.clamp(0.0, 1.0), minHeight: 8),
            const SizedBox(height: 6),
            Text(l10n.modelScoreNote, style: theme.textTheme.bodySmall),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.otherClassesTitle, style: theme.textTheme.titleSmall),
              for (final entry in others)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Expanded(child: Text(localizedClassName(l10n, entry.key))),
                    Text(_percent(context, entry.value)),
                  ]),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class FailureView extends StatelessWidget {
  const FailureView({super.key, required this.failure, required this.onRetry});

  final ApiFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('error_card'),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  failureMessage(l10n, failure.kind),
                  key: const Key('error_message'),
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ]),
            if (failure.isRetryable && onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                key: const Key('retry_button'),
                onPressed: onRetry,
                child: Text(l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
