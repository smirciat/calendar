import 'package:flutter/material.dart';

import 'package:family_calendar/services/api_client.dart';

class KioskPairingScreen extends StatefulWidget {
  const KioskPairingScreen({
    super.key,
    required this.defaultServerUrl,
    required this.onPaired,
  });

  final String defaultServerUrl;
  final void Function(String token, String serverUrl) onPaired;

  @override
  State<KioskPairingScreen> createState() => _KioskPairingScreenState();
}

class _KioskPairingScreenState extends State<KioskPairingScreen> {
  final _serverController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _serverController.text = widget.defaultServerUrl;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ApiClient(baseUrl: _serverController.text.trim());
      final token = await api.pairDevice(code: _codeController.text.trim());
      widget.onPaired(token, _serverController.text.trim());
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wall display setup')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Enter the server URL and pairing code from a phone.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _serverController,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Pairing code',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _pair,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Pair display'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
