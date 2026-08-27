import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:family_calendar/services/kiosk_update_service.dart';

Future<void> showKioskAdminSheet(
  BuildContext context, {
  required KioskUpdateService updateService,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _KioskAdminSheet(updateService: updateService),
  );
}

class _KioskAdminSheet extends StatefulWidget {
  const _KioskAdminSheet({required this.updateService});

  final KioskUpdateService updateService;

  @override
  State<_KioskAdminSheet> createState() => _KioskAdminSheetState();
}

class _KioskAdminSheetState extends State<_KioskAdminSheet> {
  PackageInfo? _packageInfo;
  KioskUpdateInfo? _update;
  String? _status;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final info = await widget.updateService.currentPackageInfo();
      final update = await widget.updateService.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _packageInfo = info;
        _update = update;
        _status = update == null ? 'App is up to date.' : 'Update available.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadAndInstall() async {
    final update = _update;
    if (update == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _status = 'Downloading update…';
    });

    try {
      final path = await widget.updateService.downloadApk(update.apkUrl);
      if (!mounted) return;
      setState(() => _status = 'Starting install — tap Install on the system prompt.');
      await widget.updateService.installApk(path);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Wall admin', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Tap the title bar seven times to open this panel.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (_packageInfo != null)
            Text(
              'Installed: ${_packageInfo!.version}+${_packageInfo!.buildNumber}',
            ),
          if (_update != null) ...[
            const SizedBox(height: 8),
            Text(
              'Available: ${_update!.versionName}+${_update!.buildNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_update!.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_update!.releaseNotes),
            ],
          ],
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(_status!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _load,
            child: const Text('Check for updates'),
          ),
          if (_update != null) ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _downloadAndInstall,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Download and install'),
            ),
          ],
        ],
      ),
    );
  }
}
