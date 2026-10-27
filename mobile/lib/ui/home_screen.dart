import 'package:flutter/material.dart';

import '../app_services.dart';
import '../l10n/app_localizations.dart';
import '../logic/analysis_controller.dart';
import '../logic/image_source_service.dart';
import '../logic/session_controller.dart';
import 'auth_screen.dart';
import 'history_screen.dart';
import 'localized_text.dart';
import 'result_view.dart';

enum _AccountAction { signIn, history, signOut, deleteAccount }

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          ListenableBuilder(
            listenable: services.session,
            builder: (context, _) => _AccountMenu(services: services),
          ),
          PopupMenuButton<Locale>(
            key: const Key('language_menu'),
            tooltip: l10n.language,
            icon: const Icon(Icons.translate),
            onSelected: services.locale.setLocale,
            itemBuilder: (_) => [
              PopupMenuItem(value: const Locale('fr'), child: Text(l10n.languageFrench)),
              PopupMenuItem(value: const Locale('ar'), child: Text(l10n.languageArabic)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([services.analysis, services.session]),
          builder: (context, _) => _Body(services: services),
        ),
      ),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.services});

  final AppServices services;

  Future<void> _onSelected(BuildContext context, _AccountAction action) async {
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case _AccountAction.signIn:
        await Navigator.of(context).push(
          MaterialPageRoute<bool>(builder: (_) => AuthScreen(session: services.session)),
        );
      case _AccountAction.history:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => HistoryScreen(services: services)),
        );
      case _AccountAction.signOut:
        services.history.clear();
        await services.session.signOut();
      case _AccountAction.deleteAccount:
        final confirmed = await confirmDialog(
          context,
          title: l10n.deleteAccountTitle,
          body: l10n.deleteAccountBody,
          confirmLabel: l10n.delete,
        );
        if (!confirmed) return;
        final ok = await services.session.deleteAccount();
        if (ok) services.history.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = services.session;
    if (!session.isSignedIn) {
      return IconButton(
        key: const Key('sign_in_button'),
        tooltip: l10n.signIn,
        icon: const Icon(Icons.account_circle_outlined),
        onPressed: session.status == SessionStatus.restoring ? null : () => _onSelected(context, _AccountAction.signIn),
      );
    }
    return PopupMenuButton<_AccountAction>(
      key: const Key('account_menu'),
      tooltip: l10n.account,
      icon: const Icon(Icons.account_circle),
      onSelected: (action) => _onSelected(context, action),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            session.user == null ? l10n.signedInUnknown : l10n.signedInAs(session.user!.email),
            key: const Key('account_label'),
          ),
        ),
        PopupMenuItem(
          value: _AccountAction.history,
          key: const Key('menu_history'),
          child: Text(l10n.history),
        ),
        PopupMenuItem(
          value: _AccountAction.signOut,
          key: const Key('menu_sign_out'),
          child: Text(l10n.signOut),
        ),
        PopupMenuItem(
          value: _AccountAction.deleteAccount,
          key: const Key('menu_delete_account'),
          child: Text(l10n.deleteAccount),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = services.analysis;
    final session = services.session;
    final image = controller.image;
    final busy = controller.isLoading;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.tagline, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (session.sessionExpired)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(l10n.sessionExpired, key: const Key('session_expired')),
          ),
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
        if (!session.isSignedIn && session.status != SessionStatus.restoring)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.signInToSaveHint, key: const Key('sign_in_hint'), style: Theme.of(context).textTheme.bodySmall),
          ),
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
          if (controller.savedToHistory)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l10n.savedToHistory, key: const Key('saved_note'), style: Theme.of(context).textTheme.bodySmall),
            ),
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
        if (session.failure != null && !session.isBusy && session.isSignedIn)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(failureMessage(l10n, session.failure!.kind), key: const Key('session_error')),
          ),
      ],
    );
  }
}
