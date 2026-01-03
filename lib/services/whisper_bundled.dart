import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

class WhisperBundled {
  static Future<String> getWhisperExecutablePath() async {
    final appDir = await getApplicationSupportDirectory();
    final whisperDir = Directory('${appDir.path}/whisper');
    
    if (!whisperDir.existsSync()) {
      whisperDir.createSync(recursive: true);
    }
    
    String assetPath;
    String execName = 'whisper-cli';
    List<String> additionalFiles = [];
    
    if (Platform.isMacOS) {
      assetPath = 'assets/whisper/macos/whisper-cli';
      // Metal libraries needed on macOS
      additionalFiles = [
        'assets/whisper/macos/libggml-metal.dylib',
        'assets/whisper/macos/libggml.dylib',
        'assets/whisper/macos/libggml-cpu.dylib',
        'assets/whisper/macos/libggml-base.dylib',
      ];
    } else if (Platform.isLinux) {
      assetPath = 'assets/whisper/linux/whisper-cli';
    } else if (Platform.isWindows) {
      assetPath = 'assets/whisper/windows/whisper-cli.exe';
      execName = 'whisper-cli.exe';
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
    } else {
      throw UnsupportedError('Platform ${Platform.operatingSystem} not supported');
    }
    
    final execPath = '${whisperDir.path}/$execName';
    final execFile = File(execPath);
    
    if (!execFile.existsSync()) {
      print('Extracting whisper binary from $assetPath to $execPath');
      final byteData = await rootBundle.load(assetPath);
      await execFile.writeAsBytes(byteData.buffer.asUint8List());
      
      // Extract additional files (Metal libraries on macOS)
      for (final additionalAsset in additionalFiles) {
        try {
          final fileName = additionalAsset.split('/').last;
          final destPath = '${whisperDir.path}/$fileName';
          final destFile = File(destPath);
          
          print('Extracting $fileName');
          final additionalData = await rootBundle.load(additionalAsset);
          await destFile.writeAsBytes(additionalData.buffer.asUint8List());
        } catch (e) {
          print('Warning: Could not extract $additionalAsset: $e');
        }
      }
      
      if (!Platform.isWindows) {
        final chmodResult = await Process.run('chmod', ['+x', execPath]);
        if (chmodResult.exitCode != 0) {
          throw Exception('Failed to make whisper executable: ${chmodResult.stderr}');
        }
      }
      
      print('Whisper binary extracted successfully');
    } else {
      print('Using existing whisper binary at $execPath');
    }
    
    return execPath;
  }
}