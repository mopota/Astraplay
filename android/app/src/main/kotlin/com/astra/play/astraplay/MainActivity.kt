package com.astra.play.astraplay

import android.content.res.Configuration
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
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
}
