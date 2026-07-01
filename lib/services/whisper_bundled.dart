import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as path;

class WhisperBundled {
  static Future<void> _unblockWindowsFile(String filePath) async {
    if (!Platform.isWindows) return;

    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Unblock-File -Path "$filePath"',
        ],
      ).timeout(const Duration(seconds: 5));

      if (result.exitCode != 0) {
        print('Warning: Unblock-File failed for $filePath: ${result.stderr}');
      }
    } catch (e) {
      print('Warning: Could not unblock $filePath: $e');
    }
  }

  static Future<String> getWhisperExecutablePath() async {
    if (Platform.isMacOS) {
      final executableDir = File(Platform.resolvedExecutable).parent.path;
      final whisperDir = '$executableDir/../Resources/whisper';
      final whisperCliPath = '$whisperDir/whisper-cli';

      if (File(whisperCliPath).existsSync()) {
        print('Using bundled whisper from app resources: $whisperCliPath');
        return whisperCliPath;
      }
    } else if (Platform.isWindows) {
      final executablePath = Platform.resolvedExecutable;
      final executableDir = path.dirname(executablePath);
      final whisperDir = path.join(executableDir, 'whisper');
      final whisperCliPath = path.join(whisperDir, 'whisper-cli.exe');

      if (File(whisperCliPath).existsSync()) {
        print('Using bundled whisper from app: $whisperCliPath');
        // Defensive: if the installer itself carried a Mark-of-the-Web,
        // Windows can sometimes propagate that zone tag to files it installs
        // alongside it. Cheap no-op if the file is already unblocked.
        await _unblockWindowsFile(whisperCliPath);
        if (Directory(whisperDir).existsSync()) {
          for (final entity in Directory(whisperDir).listSync()) {
            if (entity is File && entity.path.toLowerCase().endsWith('.dll')) {
              await _unblockWindowsFile(entity.path);
            }
          }
        }
        return whisperCliPath;
      }
    } else if (Platform.isLinux) {
      final executablePath = Platform.resolvedExecutable;
      final executableDir = path.dirname(executablePath);
      final whisperDir = path.join(executableDir, 'whisper');
      final whisperCliPath = path.join(whisperDir, 'whisper-cli');

      if (File(whisperCliPath).existsSync()) {
        print('Using bundled whisper from app: $whisperCliPath');
        return whisperCliPath;
      }
    }

    final appDir = await getApplicationSupportDirectory();
    final whisperDir = Directory('${appDir.path}/whisper');

    if (!whisperDir.existsSync()) {
      whisperDir.createSync(recursive: true);
    }

    String assetPath;
    String execName = 'whisper-cli';
    List<String> additionalFiles = [];

    if (Platform.isLinux) {
      assetPath = 'assets/whisper/linux/whisper-cli';
      additionalFiles = [
        'assets/whisper/linux/libwhisper.so',
        'assets/whisper/linux/libwhisper.so.1',
        'assets/whisper/linux/libwhisper.so.1.8.2',
      ];
    } else if (Platform.isWindows) {
      assetPath = 'assets/whisper/windows/whisper-cli.exe';
      execName = 'whisper-cli.exe';
      additionalFiles = [
        'assets/whisper/windows/whisper.dll',
        'assets/whisper/windows/ggml.dll',
        'assets/whisper/windows/ggml-base.dll',
        'assets/whisper/windows/ggml-cpu.dll',
      ];
    } else if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final abis = androidInfo.supportedAbis;

      String abi;
      if (abis.contains('arm64-v8a')) {
        abi = 'arm64-v8a';
      } else if (abis.contains('armeabi-v7a')) {
        abi = 'armeabi-v7a';
      } else {
        throw UnsupportedError('Unsupported Android ABI: $abis');
      }

      assetPath = 'assets/whisper/android/$abi/whisper-cli';
      additionalFiles = [
        'assets/whisper/android/$abi/libwhisper.so',
        'assets/whisper/android/$abi/libggml.so',
        'assets/whisper/android/$abi/libggml-base.so',
        'assets/whisper/android/$abi/libggml-cpu.so',
      ];
    } else {
      throw UnsupportedError(
          'Platform ${Platform.operatingSystem} not supported');
    }

    final execPath = '${whisperDir.path}/$execName';
    final execFile = File(execPath);

    if (!execFile.existsSync()) {
      print('Extracting whisper binary from $assetPath to $execPath');
      final byteData = await rootBundle.load(assetPath);
      await execFile.writeAsBytes(byteData.buffer.asUint8List());

      if (Platform.isWindows) {
        await _unblockWindowsFile(execPath);
      }

      for (final additionalAsset in additionalFiles) {
        try {
          final fileName = additionalAsset.split('/').last;
          final destPath = '${whisperDir.path}/$fileName';
          final destFile = File(destPath);

          print('Extracting $fileName from $additionalAsset');
          final additionalData = await rootBundle.load(additionalAsset);
          await destFile.writeAsBytes(additionalData.buffer.asUint8List());
          print(
              'Successfully extracted $fileName (${additionalData.lengthInBytes} bytes)');

          if (Platform.isWindows) {
            await _unblockWindowsFile(destPath);
          }
        } catch (e) {
          print('Warning: Could not extract $additionalAsset: $e');
        }
      }

      if (!Platform.isWindows) {
        final chmodResult = await Process.run('chmod', ['+x', execPath]);
        if (chmodResult.exitCode != 0) {
          throw Exception(
              'Failed to make whisper executable: ${chmodResult.stderr}');
        }
      }

      print('Whisper binary extracted successfully');
    } else if (Platform.isWindows) {
      // File already extracted from a prior run - still worth unblocking
      // defensively in case it was blocked after the fact (e.g. by an AV
      // scan) or the app was updated without re-running extraction.
      await _unblockWindowsFile(execPath);
      for (final additionalAsset in additionalFiles) {
        final fileName = additionalAsset.split('/').last;
        final destPath = '${whisperDir.path}/$fileName';
        if (File(destPath).existsSync()) {
          await _unblockWindowsFile(destPath);
        }
      }
    }

    return execPath;
  }
}
