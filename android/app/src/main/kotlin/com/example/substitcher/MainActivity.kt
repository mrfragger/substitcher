package com.example.substitcher

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.substitcher/open_file"
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent) {
        if (intent.action == Intent.ACTION_VIEW) {
            intent.data?.path?.let { path ->
                if (path.endsWith(".opus")) {
                    flutterEngine?.dartExecutor?.let { executor ->
                        MethodChannel(executor.binaryMessenger, CHANNEL)
                            .invokeMethod("openFile", path)
                    }
                }
            }
        }
    }
}