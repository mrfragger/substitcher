import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

class WhisperBundled {
  static Future<String> getWhisperExecutablePath() async {
    if (Platform.isMacOS) {
      final executableDir = File(Platform.resolvedExecutable).parent.path;
      final whisperDir = '$executableDir/../Resources/whisper';
      final whisperCliPath = '$whisperDir/whisper-cli';
      
      if (File(whisperCliPath).existsSync()) {
        print('Using bundled whisper from app resources: $whisperCliPath');
        return whisperCliPath;
      }
    }
    
    // Fallback to extracting from assets for other platforms
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
      throw UnsupportedError('Platform ${Platform.operatingSystem} not supported');
    }
    
    final execPath = '${whisperDir.path}/$execName';
    final execFile = File(execPath);
    
    if (!execFile.existsSync()) {
      print('Extracting whisper binary from $assetPath to $execPath');
      final byteData = await rootBundle.load(assetPath);
      await execFile.writeAsBytes(byteData.buffer.asUint8List());
      
      for (final additionalAsset in additionalFiles) {
        try {
          final fileName = additionalAsset.split('/').last;
          final destPath = '${whisperDir.path}/$fileName';
          final destFile = File(destPath);
          
          print('Extracting $fileName from $additionalAsset');
          final additionalData = await rootBundle.load(additionalAsset);
          await destFile.writeAsBytes(additionalData.buffer.asUint8List());
          print('Successfully extracted $fileName (${additionalData.lengthInBytes} bytes)');
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
    }
    
    return execPath;
  }
}