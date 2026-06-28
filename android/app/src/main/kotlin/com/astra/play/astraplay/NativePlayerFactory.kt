package com.astra.play.astraplay

import android.app.Activity
import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class NativePlayerFactory(
    private val messenger: BinaryMessenger,
    private val activity: Activity
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private var activeViews = mutableSetOf<NativePlayerView>()

    @Suppress("UNCHECKED_CAST")
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<String, Any>?
        val view = NativePlayerView(context, activity, messenger, viewId, creationParams)
        activeViews.add(view)
        return object : PlatformView by view {
            override fun dispose() {
                activeViews.remove(view)
                view.dispose()
            }
        }
    }

    fun notifyPiPChanged(isInPiP: Boolean) {
        activeViews.forEach { it.setPiPMode(isInPiP) }
    }
}
