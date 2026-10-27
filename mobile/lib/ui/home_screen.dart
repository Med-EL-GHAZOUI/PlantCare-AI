import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../logic/analysis_controller.dart';
import '../logic/image_source_service.dart';
import '../logic/locale_controller.dart';
import 'result_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller, required this.localeController});

  final AnalysisController controller;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          PopupMenuButton<Locale>(
            key: const Key('language_menu'),
            tooltip: l10n.language,
            icon: const Icon(Icons.translate),
            onSelected: localeController.setLocale,
            itemBuilder: (_) => [
              PopupMenuItem(value: const Locale('fr'), child: Text(l10n.languageFrench)),
              PopupMenuItem(value: const Locale('ar'), child: Text(l10n.languageArabic)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _Body(controller: controller),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final AnalysisController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final image = controller.image;
    final busy = controller.isLoading;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.tagline, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (image == null)
          Text(l10n.emptyHint, key: const Key('empty_hint'))
        else
          Semantics(
            label: l10n.selectedImage,
            image: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.memory(
                  image.bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image, size: 48)),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              key: const Key('camera_button'),
              onPressed: busy ? null : () => controller.pickAndAnalyze(ImageOrigin.camera),
              icon: const Icon(Icons.photo_camera),
              label: Text(l10n.takePhoto),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('gallery_button'),
              onPressed: busy ? null : () => controller.pickAndAnalyze(ImageOrigin.gallery),
              icon: const Icon(Icons.photo_library),
              label: Text(l10n.chooseFromGallery),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        if (busy)
          Semantics(
            liveRegion: true,
            label: l10n.analyzing,
            child: Column(children: [
              const LinearProgressIndicator(key: Key('loading_indicator')),
              const SizedBox(height: 8),
              Text(l10n.analyzing),
            ]),
          ),
        if (controller.status == AnalysisStatus.success && controller.prediction != null) ...[
          PredictionView(prediction: controller.prediction!),
          const SizedBox(height: 8),
          const DisclaimerCard(),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('new_analysis_button'),
            onPressed: controller.reset,
            child: Text(l10n.newAnalysis),
          ),
        ],
        if (controller.status == AnalysisStatus.failure && controller.failure != null)
          FailureView(
            failure: controller.failure!,
            onRetry: controller.image == null ? null : controller.retry,
          ),
      ],
    );
  }
}
