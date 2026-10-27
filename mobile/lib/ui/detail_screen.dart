import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../logic/detail_controller.dart';
import 'history_screen.dart';
import 'result_view.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.services, required this.record});

  final AppServices services;
  final AnalysisRecord record;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late final DetailController _controller = DetailController(
    api: widget.services.accountApi,
    session: widget.services.session,
    analysisId: widget.record.id,
    initial: widget.record,
  );

  @override
  void initState() {
    super.initState();
    _controller.load(); // rafraîchit depuis le serveur ; la version de la liste s'affiche déjà
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDialog(
      context,
      title: l10n.deleteAnalysisTitle,
      body: l10n.deleteAnalysisBody,
      confirmLabel: l10n.delete,
    );
    if (!confirmed || !mounted) return;
    final ok = await _controller.delete();
    if (!mounted || !ok) return;
    await widget.services.history.refresh();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.analysisDeleted)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.detailTitle)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final record = _controller.record;
            if (record == null) {
              if (_controller.status == DetailStatus.failure && _controller.failure != null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: FailureView(failure: _controller.failure!, onRetry: _controller.load),
                );
              }
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.analyzedOn(formatDate(context, record.createdAt)), key: const Key('detail_date')),
                const SizedBox(height: 4),
                Text(l10n.modelVersionLabel(record.modelVersion), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                PredictionView(prediction: record.toPrediction()),
                const SizedBox(height: 8),
                const DisclaimerCard(),
                if (_controller.failure != null) ...[
                  const SizedBox(height: 8),
                  FailureView(failure: _controller.failure!, onRetry: null),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('detail_delete_button'),
                  onPressed: _controller.isDeleting ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.deleteAnalysis),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
