import 'package:flutter/material.dart';

import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../logic/export_controller.dart';
import 'result_view.dart';

/// Export du résultat : option de filigrane et bouton d'export/partage de l'image annotée.
class ExportCard extends StatelessWidget {
  const ExportCard({super.key, required this.controller, required this.image});

  final ExportController controller;
  final PickedImage image;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final busy = controller.isExporting;
        return Card(
          key: const Key('export_card'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.exportTitle, style: Theme.of(context).textTheme.titleSmall),
                SwitchListTile(
                  key: const Key('export_watermark_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.exportWatermarkOption),
                  value: controller.watermark,
                  onChanged: busy ? null : (value) => controller.watermark = value,
                ),
                FilledButton.tonalIcon(
                  key: const Key('export_button'),
                  onPressed: busy
                      ? null
                      : () => controller.export(image, shareText: l10n.exportShareText),
                  icon: const Icon(Icons.ios_share),
                  label: Text(l10n.exportButton),
                ),
                if (busy) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(key: Key('export_progress')),
                  const SizedBox(height: 4),
                  Text(l10n.exportingLabel, style: Theme.of(context).textTheme.bodySmall),
                ],
                if (controller.failure != null) ...[
                  const SizedBox(height: 8),
                  FailureView(failure: controller.failure!, onRetry: controller.retry),
                ],
                const SizedBox(height: 8),
                Text(l10n.exportNote, key: const Key('export_note'), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        );
      },
    );
  }
}
