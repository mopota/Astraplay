package com.astra.play.astraplay

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Color
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import androidx.annotation.OptIn
import androidx.media3.common.*
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.HttpDataSource
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import androidx.media3.cast.CastPlayer
import androidx.media3.cast.SessionAvailabilityListener
import com.google.android.gms.cast.framework.CastContext
import androidx.mediarouter.media.MediaRouter
import androidx.mediarouter.media.MediaRouteSelector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

@OptIn(UnstableApi::class)
class NativePlayerView(
    private val context: Context,
    private val activity: Activity?,
    messenger: BinaryMessenger,
    private val id: Int,
    creationParams: Map<String, Any>?
) : PlatformView, MethodChannel.MethodCallHandler, Player.Listener {

    private val TAG = "NativePlayerView"
    private var exoPlayer: ExoPlayer? = null
    private var castPlayer: CastPlayer? = null
    private var currentPlayer: Player? = null
    private var isReleased = false

    private val mediaRouter: MediaRouter = MediaRouter.getInstance(context)
    private val mediaRouteSelector: MediaRouteSelector = MediaRouteSelector.Builder()
        .addControlCategory(com.google.android.gms.cast.CastMediaControlIntent.categoryForCast(com.google.android.gms.cast.CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID))
        .build()

    private val mediaRouterCallback = object : MediaRouter.Callback() {
        override fun onRouteAdded(router: MediaRouter, route: MediaRouter.RouteInfo) = updateCastAvailability()
        override fun onRouteRemoved(router: MediaRouter, route: MediaRouter.RouteInfo) = updateCastAvailability()
        override fun onRouteChanged(router: MediaRouter, route: MediaRouter.RouteInfo) = updateCastAvailability()
    }

    private fun updateCastAvailability() {
        val available = mediaRouter.isRouteAvailable(mediaRouteSelector, MediaRouter.AVAILABILITY_FLAG_IGNORE_DEFAULT_ROUTE)
        mainHandler.post {
            methodChannel.invokeMethod("onCastAvailabilityChanged", mapOf("available" to available))
        }
    }

    private val rootLayout: FrameLayout = FrameLayout(context)
    private val playerView: PlayerView = PlayerView(context)
    private val castButton: androidx.mediarouter.app.MediaRouteButton = androidx.mediarouter.app.MediaRouteButton(
        androidx.appcompat.view.ContextThemeWrapper(activity ?: context, androidx.appcompat.R.style.Theme_AppCompat_DayNight_DarkActionBar)
    )
    private val methodChannel: MethodChannel = MethodChannel(messenger, "astraplay/native_player_$id")
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isUpdatingProgress = false
    
    private val updateProgressAction = object : Runnable {
        override fun run() {
            if (isReleased) return
            currentPlayer?.let { player ->
                if (player.isPlaying) {
                    sendProgressUpdate()
                    mainHandler.postDelayed(this, 1000)
                    isUpdatingProgress = true
                } else {
                    isUpdatingProgress = false
                }
            } ?: run { isUpdatingProgress = false }
        }
    }

    private var currentUrl: String? = null
    private var currentHeaders: Map<String, String>? = null
    private var externalSubtitlePath: String? = null

    init {
        Log.d(TAG, "[#$id] Create Player")
        val bufferMs = (creationParams?.get("bufferMs") as? Int) ?: 5000
        val hardwareAcceleration = (creationParams?.get("hardwareAcceleration") as? Boolean) ?: true

        val renderersFactory = DefaultRenderersFactory(context)
            .setExtensionRendererMode(if (hardwareAcceleration) 
                DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON 
                else DefaultRenderersFactory.EXTENSION_RENDERER_MODE_OFF)
            .setEnableDecoderFallback(true)

        val player = ExoPlayer.Builder(context, renderersFactory)
            .setAudioAttributes(AudioAttributes.DEFAULT, true)
            .setHandleAudioBecomingNoisy(true)
            .setLoadControl(
                androidx.media3.exoplayer.DefaultLoadControl.Builder()
                    .setBufferDurationsMs(bufferMs, bufferMs * 3, 1500, 3000)
                    .setPrioritizeTimeOverSizeThresholds(true)
                    .build()
            )
            .build()

        exoPlayer = player
        currentPlayer = player
        
        playerView.setBackgroundColor(Color.BLACK)
        playerView.player = player
        playerView.useController = false
        playerView.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        rootLayout.addView(playerView)

        castButton.routeSelector = mediaRouteSelector
        castButton.visibility = View.GONE
        rootLayout.addView(castButton)

        setupCastPlayer()

        getSafeActivity()?.let { act ->
            act.runOnUiThread {
                act.window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
        
        player.addListener(this)
        methodChannel.setMethodCallHandler(this)

        mediaRouter.addCallback(mediaRouteSelector, mediaRouterCallback, MediaRouter.CALLBACK_FLAG_REQUEST_DISCOVERY)
        updateCastAvailability()

        val url = creationParams?.get("url") as? String
        @Suppress("UNCHECKED_CAST")
        val headers = creationParams?.get("headers") as? Map<String, String>
        if (url != null) {
            play(url, headers)
        }
        
        mainHandler.post(updateProgressAction)
    }

    private fun getSafeActivity(): Activity? {
        if (activity != null) return activity
        var currentContext = context
        while (currentContext is ContextWrapper) {
            if (currentContext is Activity) return currentContext
            currentContext = currentContext.baseContext
        }
        return null
    }

    private fun setupCastPlayer() {
        try {
            val castContext = CastContext.getSharedInstance(context)
            val cp = CastPlayer(castContext)
            castPlayer = cp
            cp.setSessionAvailabilityListener(object : SessionAvailabilityListener {
                override fun onCastSessionAvailable() {
                    Log.i(TAG, "[#$id] Chromecast Session Available")
                    switchToPlayer(cp)
                }
                override fun onCastSessionUnavailable() {
                    Log.i(TAG, "[#$id] Chromecast Session Unavailable")
                    exoPlayer?.let { switchToPlayer(it) }
                }
            })
        } catch (e: Exception) {
            Log.w(TAG, "Cast context not available: ${e.message}")
        }
    }

    private fun switchToPlayer(newPlayer: Player) {
        val player = currentPlayer ?: return
        if (player === newPlayer) return

        Log.d(TAG, "[#$id] Switch Player: ${if (player === exoPlayer) "Exo" else "Cast"} -> ${if (newPlayer === exoPlayer) "Exo" else "Cast"}")
        
        val pos = player.currentPosition
        val playWhenReady = player.playWhenReady
        
        player.stop()
        player.removeListener(this)

        if (player === exoPlayer && newPlayer === castPlayer) {
            methodChannel.invokeMethod("onCastStateChanged", mapOf("isCasting" to true))
        } else if (player === castPlayer && newPlayer === exoPlayer) {
            methodChannel.invokeMethod("onCastStateChanged", mapOf("isCasting" to false))
        }

        currentPlayer = newPlayer
        newPlayer.addListener(this)
        val exo = exoPlayer
        playerView.player = if (newPlayer === exo) exo else null
        
        currentUrl?.let { url ->
            val mediaItem = createMediaItem(url)
            newPlayer.setMediaItem(mediaItem, pos)
            newPlayer.prepare()
            newPlayer.playWhenReady = playWhenReady
        }
    }

    private fun createMediaItem(url: String): MediaItem {
        val builder = MediaItem.Builder().setUri(url)
        when {
            url.contains(".m3u8", true) -> builder.setMimeType(MimeTypes.APPLICATION_M3U8)
            url.contains(".mpd", true) -> builder.setMimeType(MimeTypes.APPLICATION_MPD)
            url.contains(".ts", true) -> builder.setMimeType(MimeTypes.VIDEO_MP2T)
        }

        externalSubtitlePath?.let { path ->
            val subFile = android.net.Uri.fromFile(java.io.File(path))
            val subtitleConfig = MediaItem.SubtitleConfiguration.Builder(subFile)
                .setMimeType(MimeTypes.APPLICATION_SUBRIP)
                .setLanguage("und")
                .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                .build()
            builder.setSubtitleConfigurations(listOf(subtitleConfig))
        }

        return builder.build()
    }

    override fun getView(): View = rootLayout

    override fun dispose() {
        if (isReleased) return
        isReleased = true
        Log.d(TAG, "[#$id] Release Player")
        
        mainHandler.removeCallbacks(updateProgressAction)
        mediaRouter.removeCallback(mediaRouterCallback)
        
        currentPlayer?.removeListener(this)
        exoPlayer?.let { player ->
            player.stop()
            player.release()
        }
        exoPlayer = null
        castPlayer?.release()
        castPlayer = null
        currentPlayer = null
        
        playerView.player = null
        methodChannel.setMethodCallHandler(null)

        getSafeActivity()?.let { act ->
            act.runOnUiThread {
                act.window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                val url = call.argument<String>("url")
                @Suppress("UNCHECKED_CAST")
                val headers = call.argument<Map<String, String>>("headers")
                if (url != null) {
                    play(url, headers)
                    result.success(null)
                } else {
                    result.error("INVALID_URL", "URL is null", null)
                }
            }
            "pause" -> { currentPlayer?.pause(); result.success(null) }
            "resume" -> { currentPlayer?.play(); result.success(null) }
            "seekTo" -> {
                val pos = (call.argument<Int>("position") ?: 0).toLong()
                currentPlayer?.seekTo(pos)
                result.success(null)
            }
            "setPlaybackSpeed" -> {
                val speed = (call.argument<Double>("speed") ?: 1.0).toFloat()
                currentPlayer?.playbackParameters = PlaybackParameters(speed)
                result.success(null)
            }
            "setResizeMode" -> {
                val mode = call.argument<Int>("mode") ?: AspectRatioFrameLayout.RESIZE_MODE_FIT
                playerView.resizeMode = mode
                result.success(null)
            }
            "selectTrack" -> {
                val type = call.argument<Int>("type") ?: C.TRACK_TYPE_VIDEO
                val gIdx = call.argument<Int>("groupIndex") ?: -1
                val tIdx = call.argument<Int>("trackIndex") ?: -1
                selectTrack(type, gIdx, tIdx)
                result.success(null)
            }
            "enterPiP" -> {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    getSafeActivity()?.let { act ->
                        val builder = android.app.PictureInPictureParams.Builder()
                        exoPlayer?.videoSize?.let { size ->
                            if (size.width > 0 && size.height > 0) {
                                try { builder.setAspectRatio(android.util.Rational(size.width, size.height)) } catch (e: Exception) {}
                            }
                        }
                        result.success(act.enterPictureInPictureMode(builder.build()))
                    } ?: result.error("NO_ACTIVITY", "Activity is null", null)
                } else result.error("NOT_SUPPORTED", "PiP not supported", null)
            }
            "setVolume" -> {
                val vol = (call.argument<Double>("volume") ?: 1.0).toFloat()
                if (currentPlayer === exoPlayer) {
                    val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    am.setStreamVolume(AudioManager.STREAM_MUSIC, (vol * max).toInt(), 0)
                }
                result.success(null)
            }
            "setBrightness" -> {
                val br = (call.argument<Double>("brightness") ?: 0.5).toFloat()
                getSafeActivity()?.let { a -> a.runOnUiThread {
                    val lp = a.window.attributes
                    lp.screenBrightness = br
                    a.window.attributes = lp
                }}
                result.success(null)
            }
            "getVolume" -> {
                val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                val cur = am.getStreamVolume(AudioManager.STREAM_MUSIC)
                result.success(cur.toDouble() / max)
            }
            "getBrightness" -> {
                val br = getSafeActivity()?.window?.attributes?.screenBrightness ?: 0.5f
                result.success(if (br < 0) 0.5 else br.toDouble())
            }
            "setRotation" -> { playerView.rotation = (call.argument<Int>("rotation") ?: 0).toFloat(); result.success(null) }
            "setSubtitleSource" -> { externalSubtitlePath = call.argument<String>("path"); refreshMediaItem(); result.success(null) }
            "setSubtitleStyle" -> {
                val fSize = call.argument<Double>("fontSize")?.toFloat() ?: 18f
                val col = call.argument<String>("color") ?: "White"
                val bg = call.argument<String>("backgroundColor") ?: "Black Transparent"
                updateSubtitleStyle(fSize, col, bg)
                result.success(null)
            }
            "toggleOrientation" -> {
                getSafeActivity()?.let { act ->
                    val cur = act.resources.configuration.orientation
                    act.requestedOrientation = if (cur == Configuration.ORIENTATION_LANDSCAPE) ActivityInfo.SCREEN_ORIENTATION_PORTRAIT else ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                    result.success(null)
                } ?: result.error("NO_ACTIVITY", "Activity is null", null)
            }
            "isCastAvailable" -> result.success(castPlayer?.isCastSessionAvailable == true)
            "showCastDialog" -> { getSafeActivity()?.runOnUiThread { castButton.performClick() }; result.success(null) }
            else -> result.notImplemented()
        }
    }

    private fun selectTrack(type: Int, gIdx: Int, tIdx: Int) {
        val player = currentPlayer ?: return
        val tracks = player.currentTracks
        if (gIdx == -1) {
            player.trackSelectionParameters = player.trackSelectionParameters.buildUpon().setTrackTypeDisabled(type, type == C.TRACK_TYPE_TEXT).clearOverridesOfType(type).build()
            return
        }
        var curGIdx = 0
        for (group in tracks.groups) {
            if (group.type == type) {
                if (curGIdx == gIdx) {
                    player.trackSelectionParameters = player.trackSelectionParameters.buildUpon().setTrackTypeDisabled(type, false).setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, tIdx)).build()
                    return
                }
                curGIdx++
            }
        }
    }

    private fun getTracksInfo(): Map<String, Any> {
        val player = currentPlayer ?: return emptyMap()
        val tracks = player.currentTracks
        val video = mutableListOf<Map<String, Any>>(); val audio = mutableListOf<Map<String, Any>>(); val sub = mutableListOf<Map<String, Any>>()
        var v = 0; var a = 0; var s = 0
        for (group in tracks.groups) {
            val typeIdx = when (group.type) { C.TRACK_TYPE_VIDEO -> v++; C.TRACK_TYPE_AUDIO -> a++; C.TRACK_TYPE_TEXT -> s++; else -> -1 }
            if (typeIdx == -1) continue
            for (i in 0 until group.length) {
                val f = group.getTrackFormat(i)
                val info = mapOf("groupIndex" to typeIdx, "trackIndex" to i, "label" to (f.label ?: f.language ?: "Track $i"), "isSelected" to group.isTrackSelected(i))
                when (group.type) { C.TRACK_TYPE_VIDEO -> video.add(info); C.TRACK_TYPE_AUDIO -> audio.add(info); C.TRACK_TYPE_TEXT -> sub.add(info) }
            }
        }
        return mapOf("video" to video, "audio" to audio, "subtitles" to sub)
    }

    private fun updateSubtitleStyle(fSize: Float, col: String, bg: String) {
        val textColor = when (col) { "Yellow" -> Color.YELLOW; "Green" -> Color.GREEN; "Cyan" -> Color.CYAN; else -> Color.WHITE }
        val bgColor = when (bg) { "Black" -> Color.BLACK; "Black Transparent" -> Color.parseColor("#80000000"); else -> Color.TRANSPARENT }
        val subId = context.resources.getIdentifier("exo_subtitles", "id", context.packageName)
        val view = if (subId != 0) playerView.findViewById<View>(subId) else null
        if (view is androidx.media3.ui.SubtitleView) {
            view.setFixedTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, fSize)
            view.setApplyEmbeddedStyles(false)
            view.setStyle(androidx.media3.ui.CaptionStyleCompat(textColor, bgColor, Color.TRANSPARENT, androidx.media3.ui.CaptionStyleCompat.EDGE_TYPE_NONE, Color.BLACK, null))
        }
    }

    private fun sendProgressUpdate() {
        currentPlayer?.let { p ->
            methodChannel.invokeMethod("onProgress", mapOf("position" to p.currentPosition, "duration" to if (p.duration == C.TIME_UNSET) 0L else p.duration, "bufferedPosition" to p.bufferedPosition))
        }
    }

    private fun refreshMediaItem() {
        val url = currentUrl ?: return
        val pos = currentPlayer?.currentPosition ?: 0L
        val isPlaying = currentPlayer?.isPlaying ?: false
        play(url, currentHeaders)
        currentPlayer?.seekTo(pos)
        if (isPlaying) currentPlayer?.play()
    }

    private fun play(url: String, headers: Map<String, String>? = null) {
        val player = exoPlayer ?: return
        if (currentUrl == url && player.playbackState != Player.STATE_IDLE) {
            Log.d(TAG, "[#$id] Reuse Player for same URL")
            return
        }
        Log.d(TAG, "[#$id] Prepare URL: $url")
        currentUrl = url
        currentHeaders = headers
        val http = DefaultHttpDataSource.Factory().setAllowCrossProtocolRedirects(true).setUserAgent(headers?.get("User-Agent") ?: "AstraPlay/1.0")
        headers?.forEach { (k, v) -> if (k.lowercase() != "user-agent") http.setDefaultRequestProperties(mapOf(k to v)) }
        val ds = DefaultDataSource.Factory(context, http)
        val ms = DefaultMediaSourceFactory(context).setDataSourceFactory(ds)
        player.setMediaSource(ms.createMediaSource(createMediaItem(url)))
        player.prepare()
        player.play()
    }

    override fun onPlaybackStateChanged(state: Int) {
        val s = when (state) { Player.STATE_IDLE -> "IDLE"; Player.STATE_BUFFERING -> "BUFFERING"; Player.STATE_READY -> { Log.d(TAG, "[#$id] Player READY"); "READY" }; Player.STATE_ENDED -> { Log.d(TAG, "[#$id] Playback ENDED"); "ENDED" }; else -> "UNKNOWN" }
        methodChannel.invokeMethod("onPlaybackStateChanged", mapOf("state" to s))
        if (state == Player.STATE_READY) methodChannel.invokeMethod("onTracksChanged", getTracksInfo())
    }

    fun setPiPMode(inPiP: Boolean) { methodChannel.invokeMethod("onPiPModeChanged", mapOf("isInPiP" to inPiP)) }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        if (isPlaying) Log.d(TAG, "[#$id] Playback STARTED")
        methodChannel.invokeMethod("onIsPlayingChanged", mapOf("isPlaying" to isPlaying))
        if (isPlaying && !isUpdatingProgress) mainHandler.post(updateProgressAction)
    }

    override fun onTracksChanged(tracks: Tracks) { methodChannel.invokeMethod("onTracksChanged", getTracksInfo()) }
    override fun onVideoSizeChanged(size: VideoSize) { methodChannel.invokeMethod("onVideoSizeChanged", mapOf("width" to size.width, "height" to size.height)) }

    override fun onPlayerError(err: PlaybackException) {
        Log.e(TAG, "[#$id] Error: ${err.message}")
        var msg = err.message ?: "Unknown error"
        var fatal = false
        val cause = err.cause
        if (err.errorCode == PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS || cause is HttpDataSource.InvalidResponseCodeException) {
            val code = (cause as? HttpDataSource.InvalidResponseCodeException)?.responseCode ?: -1
            if (code == 458) { msg = "الرابط مرفوض من السيرفر (Error 458)"; fatal = true }
        }
        if (!fatal && (err.errorCode == PlaybackException.ERROR_CODE_IO_UNSPECIFIED || err.errorCode == PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED)) {
            Log.d(TAG, "[#$id] Automatic retry...")
            mainHandler.postDelayed({ currentPlayer?.let { val p = it.currentPosition; it.prepare(); it.seekTo(p); it.play() } }, 2000)
        }
        methodChannel.invokeMethod("onPlayerError", mapOf("message" to msg))
    }
}
