import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// GitHub repository that hosts releases (public).
const _repoSlug = 'optimumsage/terminalpos';

/// Result of an update check.
class UpdateInfo {
  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    this.notes = '',
    this.apkUrl,
    this.releaseUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String notes;
  final String? apkUrl;
  final String? releaseUrl;
}

/// Checks GitHub Releases for a newer APK and can download + launch the
/// system installer to self-update. Pure Dart networking (dart:io) so it adds
/// no HTTP dependency; the APK install is handed to the OS.
class UpdateService {
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<UpdateInfo> checkForUpdate() async {
    final current = await currentVersion();
    final release = await _fetchLatestRelease();
    if (release == null) {
      return UpdateInfo(
        currentVersion: current,
        latestVersion: current,
        hasUpdate: false,
      );
    }

    final tag = (release['tag_name'] as String? ?? '').trim();
    final latest = _normalize(tag);
    final assets = (release['assets'] as List<dynamic>? ?? []);
    String? apkUrl;
    for (final a in assets) {
      final name = (a as Map<String, dynamic>)['name'] as String? ?? '';
      if (name.toLowerCase().endsWith('.apk')) {
        apkUrl = a['browser_download_url'] as String?;
        break;
      }
    }

    return UpdateInfo(
      currentVersion: current,
      latestVersion: latest.isEmpty ? current : latest,
      hasUpdate: latest.isNotEmpty && compareVersions(latest, current) > 0,
      notes: (release['body'] as String? ?? '').trim(),
      apkUrl: apkUrl,
      releaseUrl: release['html_url'] as String?,
    );
  }

  Future<Map<String, dynamic>?> _fetchLatestRelease() async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(
          'https://api.github.com/repos/$_repoSlug/releases/latest');
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'TerminalPOS-Updater');
      request.headers
          .set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// Downloads the APK to app storage, reporting progress in [0,1], then opens
  /// the system package installer. Returns the downloaded file path.
  Future<String> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'TerminalPOS-Updater');
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('Download failed (HTTP ${response.statusCode})');
      }
      final total = response.contentLength;
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'terminalpos-update.apk'));
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      await sink.close();
      return file.path;
    } finally {
      client.close();
    }
  }

  /// Normalizes a tag like "v1.2.3" -> "1.2.3".
  String _normalize(String tag) =>
      tag.startsWith('v') ? tag.substring(1) : tag;
}

/// Semver-ish comparison. Returns >0 if [a] is newer than [b]. Compares numeric
/// dotted parts; missing parts count as 0. A pre-release suffix (e.g. "-beta")
/// is treated as older than the same base release.
int compareVersions(String a, String b) {
  ({List<int> nums, bool pre}) parse(String v) {
    final base = v.split('+').first; // drop build metadata
    final dashIndex = base.indexOf('-');
    final pre = dashIndex >= 0;
    final core = pre ? base.substring(0, dashIndex) : base;
    final nums = core
        .split('.')
        .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    return (nums: nums, pre: pre);
  }

  final pa = parse(a);
  final pb = parse(b);
  final len = pa.nums.length > pb.nums.length ? pa.nums.length : pb.nums.length;
  for (var i = 0; i < len; i++) {
    final x = i < pa.nums.length ? pa.nums[i] : 0;
    final y = i < pb.nums.length ? pb.nums[i] : 0;
    if (x != y) return x > y ? 1 : -1;
  }
  if (pa.pre != pb.pre) return pa.pre ? -1 : 1; // release > pre-release
  return 0;
}

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());
