import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../data/update_service.dart';
import '../../widgets/ui.dart';

/// About + self-update. Checks GitHub Releases for a newer APK and, if found,
/// downloads it and hands off to the Android package installer.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  String _version = '…';
  bool _checking = false;
  double? _downloadProgress;
  UpdateInfo? _info;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final v = await ref.read(updateServiceProvider).currentVersion();
    if (mounted) setState(() => _version = v);
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = null;
      _info = null;
    });
    try {
      final info = await ref.read(updateServiceProvider).checkForUpdate();
      if (!mounted) return;
      setState(() {
        _info = info;
        _status = info.hasUpdate
            ? 'Update available: v${info.latestVersion}'
            : 'You’re on the latest version (v${info.currentVersion})';
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'Check failed: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _downloadAndInstall() async {
    final info = _info;
    if (info?.apkUrl == null) return;
    setState(() => _downloadProgress = 0);
    try {
      final path = await ref.read(updateServiceProvider).downloadApk(
            info!.apkUrl!,
            onProgress: (p) {
              if (mounted) setState(() => _downloadProgress = p);
            },
          );
      if (!mounted) return;
      setState(() => _downloadProgress = null);
      final result = await OpenFilex.open(path);
      if (mounted && result.type != ResultType.done) {
        setState(() => _status =
            'Could not launch installer: ${result.message}. Enable "Install unknown apps" for TerminalPOS.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadProgress = null;
          _status = 'Update failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final downloading = _downloadProgress != null;

    return Scaffold(
      appBar: AppBar(title: const Text('About & Updates')),
      body: ListView(
        children: [
          SectionCard(
            title: 'TerminalPOS',
            icon: Icons.point_of_sale,
            subtitle: 'Thermal-printer POS invoicing',
            children: [
              LabeledRow('Installed version', 'v$_version'),
              if (info != null)
                LabeledRow('Latest version', 'v${info.latestVersion}'),
            ],
          ),
          SectionCard(
            title: 'Software update',
            icon: Icons.system_update,
            children: [
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _status!,
                    style: TextStyle(
                      color: (info?.hasUpdate ?? false)
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (info?.hasUpdate == true && info!.notes.isNotEmpty) ...[
                Text('What’s new',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(info.notes,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                const SizedBox(height: 12),
              ],
              if (downloading) ...[
                LinearProgressIndicator(value: _downloadProgress),
                const SizedBox(height: 6),
                Text('Downloading… ${((_downloadProgress ?? 0) * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _checking || downloading ? null : _check,
                    icon: _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: const Text('Check for updates'),
                  ),
                  const SizedBox(width: 12),
                  if (info?.hasUpdate == true && info!.apkUrl != null)
                    FilledButton.icon(
                      onPressed: downloading ? null : _downloadAndInstall,
                      icon: const Icon(Icons.download),
                      label: const Text('Download & install'),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
