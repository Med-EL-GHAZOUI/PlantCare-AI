import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../logic/session_controller.dart';
import 'localized_text.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Connexion ou création de compte. Se ferme (pop) dès que la session est ouverte.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.session, this.startInRegisterMode = false});

  final SessionController session;
  final bool startInRegisterMode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _registerMode = widget.startInRegisterMode;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    widget.session.clearFailure();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final password = _password.text;
    final ok = _registerMode
        ? await widget.session.register(email, password)
        : await widget.session.signIn(email, password);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_registerMode ? l10n.registerTitle : l10n.signInTitle)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.session,
          builder: (context, _) {
            final busy = widget.session.isBusy;
            final failure = widget.session.failure;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Form(
                  key: _formKey,
                  child: Column(children: [
                    TextFormField(
                      key: const Key('email_field'),
                      controller: _email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: l10n.email, border: const OutlineInputBorder()),
                      validator: (value) =>
                          _emailPattern.hasMatch((value ?? '').trim()) ? null : l10n.validationEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('password_field'),
                      controller: _password,
                      enabled: !busy,
                      obscureText: _hidePassword,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: [_registerMode ? AutofillHints.newPassword : AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        helperText: _registerMode ? l10n.passwordHint : null,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      validator: (value) => (value ?? '').length >= 10 ? null : l10n.validationPassword,
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                if (failure != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      failureMessage(l10n, failure.kind),
                      key: const Key('auth_error'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton(
                  key: const Key('auth_submit'),
                  onPressed: busy ? null : _submit,
                  child: busy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_registerMode ? l10n.register : l10n.signIn),
                ),
                TextButton(
                  key: const Key('auth_switch'),
                  onPressed: busy
                      ? null
                      : () {
                          widget.session.clearFailure();
                          setState(() => _registerMode = !_registerMode);
                        },
                  child: Text(_registerMode ? l10n.switchToSignIn : l10n.switchToRegister),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
