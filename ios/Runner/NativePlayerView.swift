import Flutter
import UIKit
import AVKit

class NativePlayerFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return NativePlayerView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger)
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
          return FlutterStandardMessageCodec.sharedInstance()
    }
}

class NativePlayerView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var channel: FlutterMethodChannel

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        _view = UIView(frame: frame)
        _view.backgroundColor = .black
        channel = FlutterMethodChannel(name: "astraplay/native_player_\(viewId)", binaryMessenger: messenger)

        super.init()

        channel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            self?.handle(call, result: result)
        })

        if let params = args as? [String: Any], let urlString = params["url"] as? String, let url = URL(string: urlString) {
            play(url: url)
        }
    }

    func view() -> UIView {
        return _view
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "play":
            if let args = call.arguments as? [String: Any], let urlString = args["url"] as? String, let url = URL(string: urlString) {
                play(url: url)
                result(nil)
            }
        case "pause":
            player?.pause()
            result(nil)
        case "resume":
            player?.play()
            result(nil)
        case "stop":
            player?.replaceCurrentItem(with: nil)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func play(url: URL) {
        player = AVPlayer(url: url)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = _view.bounds
        playerLayer?.videoGravity = .resizeAspect
        if let layer = playerLayer {
            _view.layer.addSublayer(layer)
        }
        player?.play()
    }
}
