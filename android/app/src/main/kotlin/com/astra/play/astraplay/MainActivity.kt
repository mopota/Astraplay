package com.astra.play.astraplay

import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var nativePlayerFactory: NativePlayerFactory? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        nativePlayerFactory = NativePlayerFactory(flutterEngine.dartExecutor.binaryMessenger, this)
        
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "astraplay/native_player", 
                nativePlayerFactory!!
            )
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        nativePlayerFactory?.notifyPiPChanged(isInPictureInPictureMode)
    }

    override fun onUserLeaveHint() {
        // Handle automatic PiP if necessary, but we triggered it manually from Flutter
        super.onUserLeaveHint()
    }
}
