import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_services.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../logic/history_controller.dart';
import 'detail_screen.dart';
import 'localized_text.dart';
import 'result_view.dart';

String formatDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMd(locale).add_Hm().format(date);
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          key: const Key('dialog_cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('dialog_confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryController get _history => widget.services.history;

  @override
  void initState() {
    super.initState();
    widget.services.session.addListener(_leaveIfSignedOut);
    _history.refresh();
  }

  @override
  void dispose() {
    widget.services.session.removeListener(_leaveIfSignedOut);
    super.dispose();
  }

  /// Session expirée ou fermée pendant la consultation : retour à l'accueil.
  void _leaveIfSignedOut() {
    if (!widget.services.session.isSignedIn && mounted) {
      _history.clear();
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _delete(AnalysisRecord record) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDialog(
      context,
      title: l10n.deleteAnalysisTitle,
      body: l10n.deleteAnalysisBody,
      confirmLabel: l10n.delete,
    );
    if (!confirmed || !mounted) return;
    final ok = await _history.delete(record.id);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.analysisDeleted)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _history,
          builder: (context, _) {
            switch (_history.status) {
              case HistoryStatus.idle:
              case HistoryStatus.loading when _history.items.isEmpty:
                return const Center(child: CircularProgressIndicator(key: Key('history_loading')));
              case HistoryStatus.failure:
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: FailureView(failure: _history.failure!, onRetry: _history.refresh),
                );
              case HistoryStatus.loading:
              case HistoryStatus.loaded:
                if (_history.items.isEmpty) {
                  return ListView(padding: const EdgeInsets.all(24), children: [
                    Text(l10n.historyEmpty, key: const Key('history_empty')),
                    const SizedBox(height: 12),
                    Text(l10n.historyPrivacy, style: Theme.of(context).textTheme.bodySmall),
                  ]);
                }
                return RefreshIndicator(
                  onRefresh: _history.refresh,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Text(l10n.historyPrivacy, style: Theme.of(context).textTheme.bodySmall),
                      ),
                      if (_history.failure != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FailureView(failure: _history.failure!, onRetry: null),
                        ),
                      for (final record in _history.items)
                        _HistoryTile(
                          record: record,
                          onOpen: () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => DetailScreen(services: widget.services, record: record),
                          )),
                          onDelete: () => _delete(record),
                        ),
                      if (_history.hasMore)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _history.isLoadingMore
                              ? const Center(child: CircularProgressIndicator())
                              : OutlinedButton(
                                  key: const Key('load_more_button'),
                                  onPressed: _history.loadMore,
                                  child: Text(l10n.loadMore),
                                ),
                        ),
                    ],
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record, required this.onOpen, required this.onDelete});

  final AnalysisRecord record;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = record.isUncertain || record.predictedClass == null
        ? l10n.historyUncertainItem
        : localizedClassName(l10n, record.predictedClass!);
    return ListTile(
      key: Key('history_item_${record.id}'),
      leading: Icon(record.isUncertain ? Icons.help_outline : Icons.eco),
      title: Text(title),
      subtitle: Text(formatDate(context, record.createdAt)),
      trailing: IconButton(
        key: Key('delete_item_${record.id}'),
        tooltip: l10n.delete,
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
      onTap: onOpen,
    );
  }
}
