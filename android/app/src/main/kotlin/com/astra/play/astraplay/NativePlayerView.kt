package com.astra.play.astraplay

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Color
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.os.Handler
import android.os.Looper
import android.media.AudioManager
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.view.WindowManager
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.common.PlaybackException
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.util.EventLogger
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

@OptIn(UnstableApi::class)
class NativePlayerView(
    private val context: Context,
    private val activity: Activity?,
    messenger: BinaryMessenger,
    id: Int,
    creationParams: Map<String, Any>?
) : PlatformView, MethodChannel.MethodCallHandler, Player.Listener {

    private fun getSafeActivity(): Activity? {
        if (activity != null) return activity
        
        var currentContext = context
        while (currentContext is ContextWrapper) {
            if (currentContext is Activity) {
                return currentContext
            }
            currentContext = currentContext.baseContext
        }
        return if (context is Activity) context else null
    }

    private val player: ExoPlayer = ExoPlayer.Builder(context)
        .setAudioAttributes(AudioAttributes.DEFAULT, true)
        .setHandleAudioBecomingNoisy(true)
        .build()

    private val rootLayout: FrameLayout = FrameLayout(context)
    private val playerView: PlayerView = PlayerView(context)
    private val methodChannel: MethodChannel = MethodChannel(messenger, "astraplay/native_player_$id")
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isUpdatingProgress = false
    private val updateProgressAction = object : Runnable {
        override fun run() {
            if (player.isPlaying) {
                sendProgressUpdate()
                mainHandler.postDelayed(this, 1000)
                isUpdatingProgress = true
            } else {
                isUpdatingProgress = false
            }
        }
    }

    private val TAG = "NativePlayerView"

    init {
        player.addAnalyticsListener(EventLogger())
        
        playerView.setBackgroundColor(Color.BLACK)
        playerView.player = player
        playerView.useController = false
        
        playerView.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        
        rootLayout.addView(playerView)
        rootLayout.keepScreenOn = true 
        
        player.addListener(this)
        methodChannel.setMethodCallHandler(this)

        val url = creationParams?.get("url") as? String
        val headers = creationParams?.get("headers") as? Map<String, String>
        if (url != null) {
            play(url, headers)
        }
        
        mainHandler.post(updateProgressAction)
    }

    private fun hideSystemUI(act: Activity) {
        act.runOnUiThread {
            @Suppress("DEPRECATION")
            act.window.addFlags(android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN)
            @Suppress("DEPRECATION")
            act.window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN
            )
        }
    }

    private fun showSystemUI(act: Activity) {
        act.runOnUiThread {
            @Suppress("DEPRECATION")
            act.window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN)
            @Suppress("DEPRECATION")
            act.window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            )
        }
    }

    override fun getView(): View {
        return rootLayout
    }

    override fun dispose() {
        mainHandler.removeCallbacks(updateProgressAction)
        player.removeListener(this)
        player.release()
        methodChannel.setMethodCallHandler(null)
        
        // Reset orientation to portrait and show system UI when leaving player
        getSafeActivity()?.let { act ->
            act.runOnUiThread {
                act.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                showSystemUI(act)
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                val url = call.argument<String>("url")
                val headers = call.argument<Map<String, String>>("headers")
                if (url != null) {
                    play(url, headers)
                    result.success(null)
                } else {
                    result.error("INVALID_URL", "URL is null", null)
                }
            }
            "pause" -> {
                player.pause()
                result.success(null)
            }
            "resume" -> {
                player.play()
                result.success(null)
            }
            "seekTo" -> {
                val pos = (call.argument<Int>("position") ?: 0).toLong()
                player.seekTo(pos)
                result.success(null)
            }
            "setPlaybackSpeed" -> {
                val speed = (call.argument<Double>("speed") ?: 1.0).toFloat()
                player.playbackParameters = PlaybackParameters(speed)
                result.success(null)
            }
            "setResizeMode" -> {
                val mode = call.argument<Int>("mode") ?: AspectRatioFrameLayout.RESIZE_MODE_FIT
                playerView.resizeMode = mode
                result.success(null)
            }
            "selectTrack" -> {
                val type = call.argument<Int>("type") ?: C.TRACK_TYPE_VIDEO
                val groupIndex = call.argument<Int>("groupIndex") ?: -1
                val trackIndex = call.argument<Int>("trackIndex") ?: -1
                selectTrack(type, groupIndex, trackIndex)
                result.success(null)
            }
            "getTracks" -> {
                result.success(getTracksInfo())
            }
            "enterPiP" -> {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    val act = getSafeActivity()
                    if (act == null) {
                        result.error("NO_ACTIVITY", "Activity is null", null)
                        return
                    }
                    val builder = android.app.PictureInPictureParams.Builder()
                    val videoSize = player.videoSize
                    if (videoSize.width > 0 && videoSize.height > 0) {
                        try {
                            val rational = android.util.Rational(videoSize.width, videoSize.height)
                            val floatRatio = videoSize.width.toFloat() / videoSize.height.toFloat()
                            if (floatRatio in 0.418f..2.39f) {
                                builder.setAspectRatio(rational)
                            }
                        } catch (e: Throwable) {
                            Log.e(TAG, "Rational error", e)
                        }
                    }
                    try {
                        val success = act.enterPictureInPictureMode(builder.build())
                        result.success(success)
                    } catch (e: Throwable) {
                        Log.e(TAG, "PiP error", e)
                        result.error("PIP_ERROR", e.message, null)
                    }
                } else {
                    result.error("NOT_SUPPORTED", "PiP not supported", null)
                }
            }
            "setVolume" -> {
                val volume = (call.argument<Double>("volume") ?: 1.0).toFloat()
                val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, (volume * maxVolume).toInt(), 0)
                result.success(null)
            }
            "setBrightness" -> {
                val brightness = (call.argument<Double>("brightness") ?: 0.5).toFloat()
                val act = getSafeActivity()
                act?.let { a ->
                    a.runOnUiThread {
                        val lp = a.window.attributes
                        lp.screenBrightness = brightness
                        a.window.attributes = lp
                    }
                }
                result.success(null)
            }
            "getVolume" -> {
                val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                result.success(currentVolume.toDouble() / maxVolume)
            }
            "getBrightness" -> {
                val act = getSafeActivity()
                val brightness = act?.window?.attributes?.screenBrightness ?: 0.5f
                result.success(if (brightness < 0) 0.5 else brightness.toDouble())
            }
            "setRotation" -> {
                val rotation = call.argument<Int>("rotation") ?: 0
                playerView.rotation = rotation.toFloat()
                result.success(null)
            }
            "toggleOrientation" -> {
                val act = getSafeActivity()
                if (act == null) {
                    result.error("NO_ACTIVITY", "Activity is null", null)
                    return
                }
                
                val orientation = act.resources.configuration.orientation
                if (orientation == Configuration.ORIENTATION_LANDSCAPE) {
                    act.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                    showSystemUI(act)
                } else {
                    act.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                    hideSystemUI(act)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun selectTrack(type: Int, groupIndex: Int, trackIndex: Int) {
        val tracks = player.currentTracks
        if (groupIndex == -1) {
            player.trackSelectionParameters = player.trackSelectionParameters
                .buildUpon()
                .setTrackTypeDisabled(type, type == C.TRACK_TYPE_TEXT)
                .clearOverridesOfType(type)
                .build()
            return
        }

        var currentGroupIdx = 0
        for (group in tracks.groups) {
            if (group.type == type) {
                if (currentGroupIdx == groupIndex) {
                    player.trackSelectionParameters = player.trackSelectionParameters
                        .buildUpon()
                        .setTrackTypeDisabled(type, false)
                        .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, trackIndex))
                        .build()
                    return
                }
                currentGroupIdx++
            }
        }
    }

    private fun getTracksInfo(): Map<String, Any> {
        val tracks = player.currentTracks
        val videoTracks = mutableListOf<Map<String, Any>>()
        val audioTracks = mutableListOf<Map<String, Any>>()
        val subtitleTracks = mutableListOf<Map<String, Any>>()

        var videoGroupIdx = 0
        var audioGroupIdx = 0
        var subtitleGroupIdx = 0

        for (group in tracks.groups) {
            val type = group.type
            val currentGroupIdx = when (type) {
                C.TRACK_TYPE_VIDEO -> videoGroupIdx++
                C.TRACK_TYPE_AUDIO -> audioGroupIdx++
                C.TRACK_TYPE_TEXT -> subtitleGroupIdx++
                else -> -1
            }

            if (currentGroupIdx == -1) continue

            for (i in 0 until group.length) {
                val format = group.getTrackFormat(i)
                val trackInfo = mapOf(
                    "groupIndex" to currentGroupIdx,
                    "trackIndex" to i,
                    "id" to (format.id ?: ""),
                    "label" to (format.label ?: ""),
                    "language" to (format.language ?: ""),
                    "isSelected" to group.isTrackSelected(i),
                    "bitrate" to format.bitrate,
                    "width" to format.width,
                    "height" to format.height
                )
                
                when (type) {
                    C.TRACK_TYPE_VIDEO -> videoTracks.add(trackInfo)
                    C.TRACK_TYPE_AUDIO -> audioTracks.add(trackInfo)
                    C.TRACK_TYPE_TEXT -> subtitleTracks.add(trackInfo)
                }
            }
        }
        
        return mapOf(
            "video" to videoTracks,
            "audio" to audioTracks,
            "subtitles" to subtitleTracks
        )
    }

    private fun sendProgressUpdate() {
        val position = player.currentPosition
        val duration = player.duration
        val bufferedPosition = player.bufferedPosition
        methodChannel.invokeMethod("onProgress", mapOf(
            "position" to position,
            "duration" to if (duration == C.TIME_UNSET) 0L else duration,
            "bufferedPosition" to bufferedPosition
        ))
    }

    private fun play(url: String, headers: Map<String, String>? = null) {
        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setUserAgent(headers?.get("User-Agent") ?: "AstraPlay/1.0")
        
        headers?.let {
            val defaultRequestProperties = mutableMapOf<String, String>()
            it.forEach { (k, v) ->
                if (k.lowercase() != "user-agent") {
                    defaultRequestProperties[k] = v
                }
            }
            httpDataSourceFactory.setDefaultRequestProperties(defaultRequestProperties)
        }

        val dataSourceFactory = DefaultDataSource.Factory(context, httpDataSourceFactory)
        val mediaSourceFactory = DefaultMediaSourceFactory(context).setDataSourceFactory(dataSourceFactory)

        val mediaItemBuilder = MediaItem.Builder().setUri(url)

        if (headers != null) {
            val drmScheme = headers["drm_scheme"] ?: headers["DRM_SCHEME"]
            val drmLicenseUrl = headers["drm_license_url"] ?: headers["DRM_LICENSE_URL"]
            
            if (drmLicenseUrl != null) {
                val uuid = when (drmScheme?.lowercase()) {
                    "widevine" -> C.WIDEVINE_UUID
                    "playready" -> C.PLAYREADY_UUID
                    "clearkey" -> C.CLEARKEY_UUID
                    else -> C.WIDEVINE_UUID
                }
                
                mediaItemBuilder.setDrmConfiguration(
                    MediaItem.DrmConfiguration.Builder(uuid)
                        .setLicenseUri(drmLicenseUrl)
                        .setMultiSession(true)
                        .build()
                )
            }
        }

        val mediaItem = mediaItemBuilder.apply {
                when {
                    url.contains(".m3u8") -> setMimeType(MimeTypes.APPLICATION_M3U8)
                    url.contains(".mpd") -> setMimeType(MimeTypes.APPLICATION_MPD)
                    url.contains(".ts") -> setMimeType(MimeTypes.VIDEO_MP2T)
                }
            }
            .build()

        val mediaSource = mediaSourceFactory.createMediaSource(mediaItem)
        
        player.setMediaSource(mediaSource)
        player.prepare()
        player.play()
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        val stateStr = when (playbackState) {
            Player.STATE_IDLE -> "IDLE"
            Player.STATE_BUFFERING -> "BUFFERING"
            Player.STATE_READY -> "READY"
            Player.STATE_ENDED -> "ENDED"
            else -> "UNKNOWN"
        }
        methodChannel.invokeMethod("onPlaybackStateChanged", mapOf("state" to stateStr))
        if (playbackState == Player.STATE_READY) {
            methodChannel.invokeMethod("onTracksChanged", getTracksInfo())
        }
    }

    fun setPiPMode(isInPiP: Boolean) {
        methodChannel.invokeMethod("onPiPModeChanged", mapOf("isInPiP" to isInPiP))
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        methodChannel.invokeMethod("onIsPlayingChanged", mapOf("isPlaying" to isPlaying))
        if (isPlaying && isUpdatingProgress == false) {
            mainHandler.post(updateProgressAction)
        }
    }

    override fun onTracksChanged(tracks: Tracks) {
        methodChannel.invokeMethod("onTracksChanged", getTracksInfo())
    }

    override fun onVideoSizeChanged(videoSize: VideoSize) {
        methodChannel.invokeMethod("onVideoSizeChanged", mapOf(
            "width" to videoSize.width,
            "height" to videoSize.height
        ))
    }

    override fun onPlayerError(error: PlaybackException) {
        methodChannel.invokeMethod("onPlayerError", mapOf(
            "message" to error.message,
            "errorCode" to error.errorCode,
            "errorCodeName" to error.errorCodeName
        ))
    }
}
