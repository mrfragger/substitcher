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
    String execName;
    
    if (Platform.isLinux) {
      assetPath = 'assets/whisper/linux/main';
      execName = 'main';
    } else if (Platform.isMacOS) {
      assetPath = 'assets/whisper/macos/main';
      execName = 'main';
    } else if (Platform.isWindows) {
      assetPath = 'assets/whisper/windows/main.exe';
      execName = 'main.exe';
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
      
      assetPath = 'assets/whisper/android/$abi/main';
      execName = 'main';
    } else {
      throw UnsupportedError('Platform ${Platform.operatingSystem} not supported');
    }
    
    final execPath = '${whisperDir.path}/$execName';
    final execFile = File(execPath);
    
    if (!execFile.existsSync()) {
      print('Extracting whisper binary from $assetPath to $execPath');
      final byteData = await rootBundle.load(assetPath);
      await execFile.writeAsBytes(byteData.buffer.asUint8List());
      
      if (!Platform.isWindows) {
        final result = await Process.run('chmod', ['+x', execPath]);
        if (result.exitCode != 0) {
          throw Exception('Failed to make whisper executable: ${result.stderr}');
        }
      }
      
      print('Whisper binary extracted successfully');
    }
    
    return execPath;
  }
}