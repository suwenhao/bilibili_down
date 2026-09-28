import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const String _baseUrlTemplate =
    "https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download";
const _validTypes = ['debug', 'base', 'full', 'audio', 'video', 'video_hw'];
const String version = "0.10.4";
// 应用启用的官方归档必须匹配本地固定哈希，禁止只信任远端可变元数据。
const Map<String, String> _pinnedOfficialArchiveSha256 = {
  'bundle-base-shared-small-lgpl-0.10.4.aar':
      '26a7239cb14789f2d89435d3f6b219de826ab37c7c6f2c33a69e7fb8e67fb9a1',
  'bundle-video-shared-lgpl-0.10.4.aar':
      'bd63dbe69abffb24c687f1cb63f3290367d5272cb6448881a89494126ed2de1c',
  'bundle-full-shared-lgpl-0.10.4.aar':
      '15b5458cd3b9a5377075c09489bd5430cc144ee204ad74190107789990df63ec',
  'bundle-base-ios-universal-small-lgpl.xcframework.zip':
      '1289afeefd7eae130315ad44f455b7274dd3d7fa8ac54f3653bbbecdd2f341c9',
  'bundle-video-ios-universal-lgpl.xcframework.zip':
      'c93cd309cc2e6bd07e77a6272389a092d33154954d8f2f672f609c9b0c494287',
  'bundle-full-ios-universal-lgpl.xcframework.zip':
      'bd0047821308e6a84a1c4316d2ce0c98dff7e189e7b65959905e1b0a2f669c2e',
  'bundle-base-macos-universal-small-lgpl.xcframework.zip':
      '6f8b0f2c9c22462290f57bf1ec67166d1429ab86414517b1f48d85632842b7a5',
  'bundle-video-macos-universal-lgpl.xcframework.zip':
      'e6a4ffbc32bc7df95c75d02d33bc1c123a5e8ce5a952d71c2b4068e8566f5d51',
  'bundle-full-macos-universal-lgpl.xcframework.zip':
      '3c9b2c03e7074b0a8ee7f3b67d5402fb9f46b57ced31746b79dcd7c918ff9935',
  'bundle-base-windows-x86_64-shared-small-lgpl.zip':
      '5e1dbae78c10f850086332404cf9430e40efb371ecbbaedfe5336d9a1c66a9da',
  'bundle-video-windows-x86_64-shared-lgpl.zip':
      'b14947999069f12cf5fe26c814642b76780ce2ed0a64ee52d0c7f5a471b83967',
  'bundle-full-windows-x86_64-shared-lgpl.zip':
      'd76d74c8458b696e0bc50fba14be00540ad0066b0c3efaf2b06e5106a9d93777',
  'bundle-base-linux-x86_64-shared-small-lgpl.zip':
      '46c78fa82f10cf821f890ea31b714f41dc07f80f7127c22cf6cb3cd7fa1b46eb',
  'bundle-video-linux-x86_64-shared-lgpl.zip':
      'dbd0b85ab8a9991d61e53182a0bc70b952bc3f8750affb170d50bcb998afd721',
  'bundle-full-linux-x86_64-shared-lgpl.zip':
      'b84011d7633416f24d0114925201119cf75e54bc1d765546ab6cefc7515d4e5f',
};

void _log(String message) => stderr.writeln('FFmpegKit [Build Hook]: $message');
Exception _exception(Object e) => Exception('FFmpegKit [Build Hook]: $e');

late final OS targetOS;
late final Architecture targetArch;

class ConfigResult {
  final dynamic config;
  final String baseDir;
  ConfigResult(this.config, this.baseDir);
}

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final packageName = input.packageName;
    targetOS = input.config.code.targetOS;
    targetArch = input.config.code.targetArchitecture;

    _log('Build Hook for $packageName on ${targetOS.name}-${targetArch.name}');

    // 1. Load Configuration
    final configResult = _loadConfig(input);
    // 应用 pubspec 决定 FFmpegKit 变体，必须纳入 Hook 依赖以正确失效缓存。
    final configFile = File(p.join(configResult.baseDir, 'pubspec.yaml'));
    if (configFile.existsSync()) output.dependencies.add(configFile.uri);

    // 2. Resolve Artifact
    final artifact = await _resolveArtifact(configResult, input);
    if (artifact == null) {
      throw _exception(
        'Failed to resolve artifact for ${targetOS.name}-${targetArch.name}',
      );
    }

    // 3. Emit Assets
    await _emitAssets(artifact, input, output);
  });
  // Hook 输出已由 build 写入磁盘，显式结束独立进程以回收残留的异步事件源。
  exit(0);
}

ConfigResult _loadConfig(BuildInput input) {
  final packageRoot = p.normalize(input.packageRoot.toFilePath());
  final packageConfig = Platform.packageConfig;

  _log('input.packageRoot: $packageRoot');
  _log('Platform.packageConfig: $packageConfig');

  // 1. Prefer consuming app config via Platform.packageConfig anchor
  if (packageConfig != null) {
    // packageConfig is a file:/// URI pointing to .dart_tool/package_config.json
    final packageConfigPath = p.normalize(
      File.fromUri(Uri.parse(packageConfig)).path,
    );
    // appRoot is two levels up from .dart_tool/package_config.json
    final appRoot = p.dirname(p.dirname(packageConfigPath));
    final appPubspec = File(p.join(appRoot, 'pubspec.yaml'));

    if (appPubspec.existsSync()) {
      final config = _parsePubspec(appPubspec);
      if (config != null) {
        _log('Using app configuration from ${appPubspec.path}');
        return ConfigResult(config, appRoot);
      }
      _log('Found app pubspec at $appRoot but no ffmpeg_kit_extended_config');
    }
  }

  // 2. Fallback to package root only if we are building the package itself
  // (e.g. during local tests or examples within the same repo)
  final pkgPubspec = File(p.join(packageRoot, 'pubspec.yaml'));
  if (pkgPubspec.existsSync()) {
    final config = _parsePubspec(pkgPubspec);
    if (config != null) {
      _log('Using package-local configuration from ${pkgPubspec.path}');
      return ConfigResult(config, packageRoot);
    }
  }

  // 3. Last Resort: Default Configuration
  stderr.writeln(
    'FFmpegKit [Build Hook]: No configuration found. Using default "base" lgpl small build.',
  );
  return ConfigResult({
    'type': 'base',
    'gpl': false,
    'small': true,
  }, packageRoot);
}

dynamic _parsePubspec(File file) {
  try {
    final content = file.readAsStringSync();
    final doc = loadYaml(content);
    return doc['ffmpeg_kit_extended_config'];
  } catch (e) {
    return null;
  }
}

class FFmpegArtifact {
  final File file;
  final Directory? extractedDir;
  final bool isAar;

  FFmpegArtifact({required this.file, this.extractedDir, this.isAar = false});
}

class AppleRuntimeLayout {
  final File frameworkBinary;
  final List<File> companionLibraries;

  AppleRuntimeLayout({
    required this.frameworkBinary,
    required this.companionLibraries,
  });
}

Future<FFmpegArtifact?> _resolveArtifact(
  ConfigResult configResult,
  BuildInput input,
) async {
  final config = configResult.config;
  String type = config['type']?.toString() ?? "full";
  if (type == "streaming") type = "video";
  if (!_validTypes.contains(type)) {
    _log(
      'Invalid bundle type: $type. Valid types are: ${_validTypes.join(', ')}',
    );
    exit(1);
  }

  final bool gpl = config['gpl'] == true;
  final bool small = config['small'] == true;
  final platformName = targetOS.name; // Use .name for stable keys
  final overrideUrl = config[platformName]?.toString();

  final cacheDir = Directory(
    p.fromUri(
      input.outputDirectoryShared.resolve('ffmpeg_kit_cache/$platformName/'),
    ),
  );
  if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);

  String filename = '';
  String url = '';

  if (overrideUrl != null) {
    if (_isUri(overrideUrl)) {
      _log('Using remote override URL: $overrideUrl');
      url = overrideUrl;
      filename = p.basename(Uri.parse(url).path);
      final targetFile = File(p.join(cacheDir.path, filename));
      if (!await _downloadFile(url, targetFile)) {
        throw _exception('Failed to download from $url.');
      }
      return await _handleDownloadedFile(targetFile, cacheDir, input);
    } else {
      _log('Using local override path: $overrideUrl');
      final localFile = p.isAbsolute(overrideUrl)
          ? File(overrideUrl)
          : File(p.join(configResult.baseDir, overrideUrl));

      if (localFile.existsSync()) {
        filename = p.basename(localFile.path);
        final cacheFile = File(p.join(cacheDir.path, filename));
        if (!cacheFile.existsSync() ||
            cacheFile.lengthSync() != localFile.lengthSync()) {
          localFile.copySync(cacheFile.path);
        }
        return await _handleDownloadedFile(cacheFile, cacheDir, input);
      }
      throw _exception(
        'Local override not found: $overrideUrl (resolved from ${configResult.baseDir})',
      );
    }
  } else {
    final license = gpl ? 'gpl' : 'lgpl';
    final currentType = type == 'debug' ? 'base' : type;

    if (targetOS == OS.android) {
      const groupIdPath = 'io/github/akashskypatel/ffmpegkit';
      final parts = ['bundle', currentType, 'shared'];
      if (type == 'debug') {
        parts.add('debug');
      } else if (small) {
        parts.add('small');
      }
      parts.add(license);
      final artifactId = parts.join('-');
      filename = "$artifactId-$version.aar";
      url =
          "https://repo1.maven.org/maven2/$groupIdPath/$artifactId/$version/$filename";
    } else if (targetOS == OS.iOS || targetOS == OS.macOS) {
      final parts = ['bundle', currentType, platformName, 'universal'];
      if (type != 'debug' && small) parts.add('small');
      parts.add(license);
      filename = "${parts.join('-')}.xcframework.zip";
      final tag = "v$version-$platformName";
      url = "$_baseUrlTemplate/$tag/$filename";
    } else {
      // Windows, Linux
      final archStr = targetArch == Architecture.x64
          ? 'x86_64'
          : (targetArch == Architecture.arm64 ? 'arm64' : 'x86_64');
      final parts = ['bundle', currentType, platformName, archStr, 'shared'];
      if (type != 'debug' && small) parts.add('small');
      parts.add(license);
      filename = "${parts.join('-')}.zip";
      final tag = "v$version-$platformName";
      url = "$_baseUrlTemplate/$tag/$filename";
    }
  }

  final targetFile = File(p.join(cacheDir.path, filename));
  if (!targetFile.existsSync()) {
    _log('Downloading $url...');
    if (!await _downloadFile(url, targetFile)) {
      throw _exception(
        'Failed to download from $url. If you are using official bundles, please upgrade your package version immediately and run `flutter clean` then re-build to download updated binaries.',
      );
    }
  }

  _log('Verifying SHA256 hash from $url');

  // 官方固定配置必须使用仓库内审计过的哈希；显式覆盖包仍读取其同源校验信息。
  final pinnedHash = overrideUrl == null
      ? _pinnedOfficialArchiveSha256[filename]
      : null;
  // 新增平台或改变包型时若未同步更新清单，应在构建阶段立即失败。
  if (overrideUrl == null && pinnedHash == null) {
    throw _exception('No pinned SHA256 hash for official archive $filename.');
  }
  // 覆盖 URL 保留原有远端校验能力，正式官方包则完全依赖固定值。
  final expectedHash = pinnedHash ?? await _fetchSha256Hash(url);
  if (expectedHash == null) {
    _log('No SHA256 hash found for $url; skipping verification');
  } else {
    final calculatedHash = await _computeFileSha256(targetFile);
    if (calculatedHash == null) {
      _log(
        'Failed to compute SHA256 hash for $targetFile; skipping verification',
      );
    } else if (expectedHash != calculatedHash) {
      throw _exception(
        'SHA256 hash mismatch: expected $expectedHash, got $calculatedHash',
      );
    }
    _log('SHA256 verification passed');
  }

  return _handleDownloadedFile(targetFile, cacheDir, input);
}

Future<FFmpegArtifact> _handleDownloadedFile(
  File file,
  Directory cacheDir,
  BuildInput input,
) async {
  if (file.path.endsWith('.aar')) {
    return FFmpegArtifact(file: file, isAar: true);
  }

  final extractRoot = Directory(
    p.join(cacheDir.path, p.basenameWithoutExtension(file.path)),
  );
  if (!extractRoot.existsSync() || extractRoot.listSync().isEmpty) {
    extractRoot.createSync(recursive: true);
    if (!await _extractFile(file, extractRoot.path)) {
      throw _exception('Failed to extract ${file.path}');
    }
  }
  // Auto-detect the xcframework directory inside
  final finalExtractedDir = extractRoot
      .listSync()
      .whereType<Directory>()
      .firstWhere(
        (d) => p.basename(d.path).endsWith('.xcframework'),
        orElse: () => Directory(
          p.join(extractRoot.path, p.basename(extractRoot.path)),
        ), // flat zip fallback
      );
  return FFmpegArtifact(file: file, extractedDir: finalExtractedDir);
}

Future<void> _emitAssets(
  FFmpegArtifact artifact,
  BuildInput input,
  BuildOutputBuilder output,
) async {
  final packageName = input.packageName;

  if (targetOS == OS.android) {
    // Extract AAR to get .so files for the target architecture
    final tempDir = Directory(
      p.fromUri(input.outputDirectory.resolve('aar_extract/')),
    );
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync(recursive: true);

    if (await _extractFile(artifact.file, tempDir.path)) {
      _log('Extracted ${artifact.file.path} to ${tempDir.path}');
    } else {
      throw _exception('Failed to extract ${artifact.file.path}');
    }
    output.dependencies.add(artifact.file.uri);
    // Find jniLibs
    final jniDir = Directory(p.join(tempDir.path, 'jni'));
    if (!jniDir.existsSync()) {
      throw _exception('Could not find jni directory in AAR');
    }

    final abi = _getAndroidAbi();
    final abiDir = Directory(p.join(jniDir.path, abi));
    if (!abiDir.existsSync()) {
      throw _exception('Could not find ABI directory $abi in AAR');
    }

    // Find all .so files
    final soFiles =
        abiDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.so'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    // Identify the main ffmpegkit library and companion libraries
    final mainLibrary = soFiles.firstWhere(
      (file) => p.basename(file.path) == 'libffmpegkit.so',
      orElse: () => soFiles.first,
    );

    // Add the main library
    final mainName = p
        .basenameWithoutExtension(mainLibrary.path)
        .replaceFirst('lib', '');
    output.assets.code.add(
      CodeAsset(
        package: packageName,
        name: mainName,
        linkMode: DynamicLoadingBundled(),
        file: Uri.file(mainLibrary.path),
      ),
    );

    // Add companion libraries with the 'native/' prefix
    for (final file in soFiles) {
      if (file.path != mainLibrary.path) {
        final name = p.basename(file.path);
        output.assets.code.add(
          CodeAsset(
            package: packageName,
            name: 'native/$name',
            linkMode: DynamicLoadingBundled(),
            file: Uri.file(file.path),
          ),
        );
      }
    }
  } else if (targetOS == OS.iOS || targetOS == OS.macOS) {
    final runtimeLayout = await _buildAppleRuntimeFramework(
      artifact: artifact,
      input: input,
    );

    output.assets.code.add(
      CodeAsset(
        package: packageName,
        name: 'ffmpegkit',
        linkMode: DynamicLoadingBundled(),
        file: Uri.file(runtimeLayout.frameworkBinary.path),
      ),
    );

    for (final companionLibrary in runtimeLayout.companionLibraries) {
      output.assets.code.add(
        CodeAsset(
          package: packageName,
          name: 'native/${p.basename(companionLibrary.path)}',
          linkMode: DynamicLoadingBundled(),
          file: Uri.file(companionLibrary.path),
        ),
      );
    }
  } else {
    // Windows, Linux
    final libDir = artifact.extractedDir!;
    final ext = targetOS == OS.windows ? '.dll' : '.so';

    // Find all library files in the bin directory (where DLLs are typically located)
    final libFiles = <File>[];

    // Look for files in bin directory first (common for Windows)
    final binDir = Directory('${libDir.path}/bin');
    if (binDir.existsSync()) {
      libFiles.addAll(
        binDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith(ext))
            .toList(),
      );
    }

    // Also look in lib directory (common for Linux)
    final libDirPath = Directory('${libDir.path}/lib');
    if (libDirPath.existsSync()) {
      libFiles.addAll(
        libDirPath
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith(ext))
            .toList(),
      );
    }

    // Also look in the root directory
    libFiles.addAll(
      libDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith(ext))
          .toList(),
    );

    // Remove duplicates and sort
    final uniqueLibFiles = libFiles.toSet().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (uniqueLibFiles.isEmpty) {
      _log('No library files found in ${libDir.path}');
      return;
    }

    // Identify the main ffmpegkit library and companion libraries
    File mainLibrary;
    try {
      mainLibrary = uniqueLibFiles.firstWhere(
        (file) => p.basename(file.path).toLowerCase().contains('ffmpegkit'),
      );
    } catch (e) {
      // If no ffmpegkit library found, use the first library
      mainLibrary = uniqueLibFiles.first;
      _log(
        'No ffmpegkit library found, using ${p.basename(mainLibrary.path)} as main library',
      );
    }

    // Add the main library
    var mainName = p.basenameWithoutExtension(mainLibrary.path);
    if (targetOS == OS.linux) mainName = mainName.replaceFirst('lib', '');
    output.assets.code.add(
      CodeAsset(
        package: packageName,
        name: mainName,
        linkMode: DynamicLoadingBundled(),
        file: Uri.file(mainLibrary.path),
      ),
    );

    // Add companion libraries with the 'native/' prefix
    for (final file in uniqueLibFiles) {
      if (file.path != mainLibrary.path) {
        final name = p.basename(file.path);
        // For Linux, remove 'lib' prefix from companion libraries as well
        var assetName = name;
        if (targetOS == OS.linux) {
          assetName = assetName.replaceFirst('lib', '');
          // Also remove the .so extension for the asset name
          if (assetName.endsWith('.so')) {
            assetName = assetName.substring(0, assetName.length - 3);
          }
        }
        output.assets.code.add(
          CodeAsset(
            package: packageName,
            name: 'native/$assetName',
            linkMode: DynamicLoadingBundled(),
            file: Uri.file(file.path),
          ),
        );
      }
    }
  }
}

Future<AppleRuntimeLayout> _buildAppleRuntimeFramework({
  required FFmpegArtifact artifact,
  required BuildInput input,
}) async {
  final libDir = artifact.extractedDir!;
  final archStr = _getAppleArch();
  final slicePrefix = targetOS == OS.iOS ? 'ios-' : 'macos-';

  // Determine if we need a simulator or device slice.
  // For iOS, check the target SDK to disambiguate between
  // e.g. ios-arm64 and ios-arm64-simulator.
  final bool wantsSimulator =
      targetOS == OS.iOS &&
      input.config.code.iOS.targetSdk == IOSSdk.iPhoneSimulator;

  final sliceDirs = libDir
      .listSync(followLinks: false)
      .whereType<Directory>()
      .map((d) => d.path)
      .where((path) => p.basename(path).startsWith(slicePrefix))
      .toList();

  String? selectedSliceDir;
  if (targetOS == OS.iOS) {
    // iOS: disambiguate by -simulator suffix
    selectedSliceDir = sliceDirs.cast<String?>().firstWhere((path) {
      final basename = p.basename(path!);
      return wantsSimulator
          ? basename.endsWith('-simulator')
          : !basename.endsWith('-simulator');
    }, orElse: () => null);
  } else {
    // macOS: only one slice expected
    selectedSliceDir = sliceDirs.isNotEmpty ? sliceDirs.first : null;
  }

  if (selectedSliceDir == null) {
    throw _exception(
      'Could not find Apple slice${targetOS == OS.iOS ? ' (${wantsSimulator ? 'simulator' : 'device'})' : ''} starting with $slicePrefix in ${libDir.path}',
    );
  }

  final sliceDir = Directory(selectedSliceDir);

  final sourceDylibs =
      sliceDir
          .listSync(followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dylib'))
          .where((f) => !FileSystemEntity.isLinkSync(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final sourceMainDylib = sourceDylibs.firstWhere(
    (f) => p.basename(f.path) == 'libffmpegkit.dylib',
    orElse: () {
      throw _exception('libffmpegkit.dylib not found in ${sliceDir.path}');
    },
  );

  final frameworkRoot = Directory(
    p.fromUri(input.outputDirectory.resolve('ffmpegkit.framework/')),
  );
  if (frameworkRoot.existsSync()) {
    frameworkRoot.deleteSync(recursive: true);
  }

  final frameworkBinary = targetOS == OS.macOS
      ? File(p.join(frameworkRoot.path, 'Versions', 'A', 'ffmpegkit'))
      : File(p.join(frameworkRoot.path, 'ffmpegkit'));
  final headersDir = targetOS == OS.macOS
      ? Directory(p.join(frameworkRoot.path, 'Versions', 'A', 'Headers'))
      : Directory(p.join(frameworkRoot.path, 'Headers'));
  final resourcesDir = targetOS == OS.macOS
      ? Directory(p.join(frameworkRoot.path, 'Versions', 'A', 'Resources'))
      : frameworkRoot;
  final companionDir = Directory(
    p.fromUri(input.outputDirectory.resolve('native/')),
  );

  headersDir.createSync(recursive: true);
  resourcesDir.createSync(recursive: true);
  if (companionDir.existsSync()) {
    companionDir.deleteSync(recursive: true);
  }
  companionDir.createSync(recursive: true);

  await _thinOrCopyAppleBinary(
    source: sourceMainDylib,
    destination: frameworkBinary,
    archStr: archStr,
  );

  final companionLibraries = <File>[];
  for (final dylib in sourceDylibs) {
    if (dylib.path == sourceMainDylib.path) continue;
    final destination = File(p.join(companionDir.path, p.basename(dylib.path)));
    await _thinOrCopyAppleBinary(
      source: dylib,
      destination: destination,
      archStr: archStr,
    );
    companionLibraries.add(destination);
  }

  final sourceHeadersDir = Directory(p.join(sliceDir.path, 'Headers'));
  if (sourceHeadersDir.existsSync()) {
    await _copyDirectory(sourceHeadersDir, headersDir);
  }

  final infoPlist = File(p.join(resourcesDir.path, 'Info.plist'));
  infoPlist.writeAsStringSync(_appleFrameworkInfoPlist());

  if (targetOS == OS.macOS) {
    _createFrameworkSymlink(
      frameworkRoot,
      'Headers',
      'Versions/Current/Headers',
    );
    _createFrameworkSymlink(
      frameworkRoot,
      'Resources',
      'Versions/Current/Resources',
    );
    _createFrameworkSymlink(
      frameworkRoot,
      'ffmpegkit',
      'Versions/Current/ffmpegkit',
    );
    _createFrameworkSymlink(frameworkRoot, 'Versions/Current', 'A');
  }

  return AppleRuntimeLayout(
    frameworkBinary: frameworkBinary,
    companionLibraries: companionLibraries,
  );
}

Future<void> _thinOrCopyAppleBinary({
  required File source,
  required File destination,
  required String archStr,
}) async {
  destination.parent.createSync(recursive: true);
  _log('Thinning ${p.basename(source.path)} to $archStr...');

  final lipoRes = await Process.run('lipo', [
    source.path,
    '-thin',
    archStr,
    '-output',
    destination.path,
  ]);

  if (lipoRes.exitCode != 0) {
    source.copySync(destination.path);
  }
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  if (!destination.existsSync()) {
    destination.createSync(recursive: true);
  }
  await for (final entity in source.list(
    recursive: false,
    followLinks: false,
  )) {
    final targetPath = p.join(destination.path, p.basename(entity.path));
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(targetPath));
    } else if (entity is File) {
      entity.copySync(targetPath);
    }
  }
}

void _createFrameworkSymlink(
  Directory frameworkRoot,
  String name,
  String target,
) {
  final link = Link(p.join(frameworkRoot.path, name));
  if (link.existsSync()) {
    link.deleteSync();
  }
  link.createSync(target);
}

String _appleFrameworkInfoPlist() {
  final platform = targetOS == OS.macOS ? 'MacOSX' : 'iPhoneOS';
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>ffmpegkit</string>
  <key>CFBundleIdentifier</key>
  <string>io.github.akashskypatel.ffmpegkit</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>ffmpegkit</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>$platform</string>
  </array>
</dict>
</plist>
''';
}

String _getAndroidAbi() {
  if (targetArch == Architecture.arm) return 'armeabi-v7a';
  if (targetArch == Architecture.arm64) return 'arm64-v8a';
  if (targetArch == Architecture.ia32) return 'x86';
  if (targetArch == Architecture.x64) return 'x86_64';
  return 'arm64-v8a';
}

String _getAppleArch() {
  if (targetArch == Architecture.arm64) return 'arm64';
  if (targetArch == Architecture.x64) return 'x86_64';
  return 'arm64';
}

/// 下载原生包，并在临时网络或 TLS 握手失败时有限重试。
Future<bool> _downloadFile(String url, File target) async {
  final tempTarget = File('${target.path}.downloading');
  // GitHub 下载偶尔会被代理中断，最多尝试三次避免一次握手失败终止构建。
  for (var attempt = 1; attempt <= 3; attempt++) {
    // 每次重试使用独立客户端，不能复用已经进入错误状态的 TLS 连接。
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      // 只接受成功响应，其他状态码按可重试下载失败处理。
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Download failed with status ${response.statusCode}.',
          uri: Uri.parse(url),
        );
      }
      // 先完整写入临时文件，再原子替换正式缓存，避免残留半包。
      await response.pipe(tempTarget.openWrite());
      tempTarget.renameSync(target.path);
      return true;
    } catch (error) {
      // 本轮失败必须删除不完整文件，下一次尝试从头下载。
      if (tempTarget.existsSync()) tempTarget.deleteSync();
      // 最后一次失败保留原始异常和堆栈交给 Flutter 构建日志。
      if (attempt == 3) rethrow;
      // 输出不含 URL 参数的重试次数，方便判断网络问题而不泄露配置。
      _log('Download attempt $attempt failed; retrying: $error');
      // 逐次增加短暂退避，减少连续命中同一个异常连接的概率。
      await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
    } finally {
      // 构建 Hook 是短生命周期进程，强制关闭连接避免代理残留 CloseWait。
      client.close(force: true);
    }
  }
  // 循环边界保证不会到达这里，返回值仅满足静态控制流分析。
  return false;
}

Future<bool> _extractFile(File zipFile, String destPath) async {
  File? tempZipFile;
  try {
    if (Platform.isWindows) {
      final fileExt = zipFile.path.split('.').last.toLowerCase();
      if (fileExt == "aar") {
        //create temp renamed files with .aar replaced with .zip extension
        tempZipFile = zipFile.copySync(
          zipFile.path.replaceFirst('.$fileExt', '.zip'),
        );
        zipFile = tempZipFile;
      }
      final res = await Process.run('powershell', [
        '-command',
        'Expand-Archive -Path "${zipFile.path}" -DestinationPath "$destPath" -Force',
      ]);
      if (res.exitCode != 0) {
        _log(
          'Command: Expand-Archive -Path "${zipFile.path}" -DestinationPath "$destPath" -Force',
        );
        _log('Failed to extract ${zipFile.path}');
        _log('Error: ${res.stderr}');
      }
      return res.exitCode == 0;
    } else {
      final res = await Process.run('unzip', [
        '-o',
        zipFile.path,
        '-d',
        destPath,
      ]);
      if (res.exitCode != 0) {
        final res2 = await Process.run('tar', [
          '-xf',
          zipFile.path,
          '-C',
          destPath,
        ]);
        if (res2.exitCode != 0) {
          _log('Command: tar -xf ${zipFile.path} -C $destPath');
          _log('Failed to extract ${zipFile.path}');
          _log('Error: ${res2.stderr}');
        }
        return res2.exitCode == 0;
      }
      return true;
    }
  } catch (e) {
    return false;
  } finally {
    tempZipFile?.deleteSync();
  }
}

bool _isUri(String path) {
  try {
    if (path.contains("\\\\wsl.")) return false;
    final uri = Uri.parse(path);
    return uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'ftp');
  } catch (e) {
    return false;
  }
}

Future<String?> _fetchSha256Hash(String url) async {
  final client = HttpClient();
  try {
    // if github, use github api to get the file hash
    // https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/releases/${id}
    if (targetOS != OS.android) {
      // https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/releases/${id}
      // https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/releases/tags/${tag}
      final tag = "v$version-${targetOS.name}";
      final releaseName = p.basename(url);
      final request = await client.getUrl(
        Uri.parse(
          'https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/releases/tags/$tag',
        ),
      );
      final response = await request.close();
      if (response.statusCode == 200) {
        //parse json response to extract asset url
        final content = await response.transform(utf8.decoder).join();
        final json = jsonDecode(content);
        final assets = json['assets'] as List;
        for (final asset in assets) {
          if (asset['name'] == releaseName) {
            final digest = asset['digest'] as String?;
            if (digest == null || digest.isEmpty) {
              return null;
            }
            // parse 'sha256:...' format
            final parts = digest.split(':');
            if (parts.length == 2) {
              return parts[1].toLowerCase();
            }
            return digest.toLowerCase();
          }
        }
      }
    } else {
      final request = await client.getUrl(Uri.parse('$url.sha256'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        // Extract hash from standard sha256sum format: "hash  filename" or just "hash"
        final parts = content.trim().split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          return parts[0].toLowerCase();
        }
      }
    }
    return null;
  } catch (e) {
    return null;
  } finally {
    // 哈希请求完成后立即回收连接，不能让 keep-alive 阻塞 Hook 进程退出。
    client.close(force: true);
  }
}

Future<String?> _computeFileSha256(File file) async {
  try {
    final stream = file.openRead();
    final hash = await sha256.bind(stream).first;
    return hash.toString();
  } catch (e) {
    return null;
  }
}
