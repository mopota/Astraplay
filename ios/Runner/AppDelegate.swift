import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let registrar = self.registrar(forPlugin: "astraplay")
    let factory = NativePlayerFactory(messenger: registrar!.messenger())
    registrar!.register(factory, withId: "astraplay/native_player")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
