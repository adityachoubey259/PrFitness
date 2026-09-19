import 'dart:io';

import 'package:file_selector/file_selector.dart';

enum ReleaseArtifact { apk, aab }

abstract final class ReleaseDownloadService {
  static Future<String> saveArtifact(ReleaseArtifact artifact) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Release export is available in the PrFitness Windows app.',
      );
    }

    final File source = await _findSource(artifact);

    final String extension = artifact == ReleaseArtifact.apk ? 'apk' : 'aab';

    final String fileName = artifact == ReleaseArtifact.apk
        ? 'PrFitness-release.apk'
        : 'PrFitness-release.aab';

    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(
          label: artifact == ReleaseArtifact.apk
              ? 'Android APK'
              : 'Android App Bundle',
          extensions: <String>[extension],
        ),
      ],
      confirmButtonText: 'Save PrFitness',
      canCreateDirectories: true,
    );

    if (location == null) {
      return '';
    }

    await XFile(source.path).saveTo(location.path);

    return location.path;
  }

  static Future<File> _findSource(ReleaseArtifact artifact) async {
    final String fileName = artifact == ReleaseArtifact.apk
        ? 'PrFitness-release.apk'
        : 'PrFitness-release.aab';

    final String buildPath = artifact == ReleaseArtifact.apk
        ? r'C:\Projects\PrFitness\build\app\outputs\flutter-apk\app-release.apk'
        : r'C:\Projects\PrFitness\build\app\outputs\bundle\release\app-release.aab';

    final String home =
        Platform.environment['USERPROFILE'] ?? r'C:\Users\Lenovo';

    final List<File> candidates = <File>[
      File('$home\\Downloads\\PrFitness-Release\\$fileName'),
      File(buildPath),
    ];

    for (final File file in candidates) {
      if (await file.exists()) {
        return file;
      }
    }

    throw StateError('$fileName is not available yet.');
  }
}
