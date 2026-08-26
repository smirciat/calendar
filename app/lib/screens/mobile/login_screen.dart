import 'package:flutter/material.dart';

import 'package:family_calendar/services/api_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.defaultServerUrl,
    required this.onAuthenticated,
  });

  final String defaultServerUrl;
  final void Function(String token, String serverUrl) onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _serverController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _registerMode = false;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _serverController.text = widget.defaultServerUrl;
    _checkRegistration();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkRegistration() async {
    try {
      final api = ApiClient(baseUrl: _serverController.text.trim());
      final registered = await api.isRegistered();
      if (mounted) {
        setState(() {
          _registerMode = !registered;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _registerMode = false;
          _loading = false;
          _error = 'Could not reach server';
        });
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final api = ApiClient(baseUrl: _serverController.text.trim());
      final token = _registerMode
          ? await api.register(
              name: _nameController.text.trim(),
              password: _passwordController.text,
            )
          : await api.login(password: _passwordController.text);
      widget.onAuthenticated(token, _serverController.text.trim());
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_registerMode ? 'Create family' : 'Family login'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _serverController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_registerMode)
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Family name',
                border: OutlineInputBorder(),
              ),
            ),
          if (_registerMode) const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Family password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_registerMode ? 'Create family' : 'Sign in'),
          ),
        ],
      ),
    );
  }
}
