import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audioService: QuranAudioService?
  private var coreMLService: QuranCoreMLService?
  private var playbackService: QuranPlaybackService?
  private var askService: AskAIService?
  private var prayerLocationService: PrayerLocationService?
  private var qiblaCompassService: QiblaCompassService?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "QuranAudio") {
      audioService = QuranAudioService(messenger: registrar.messenger())
      coreMLService = QuranCoreMLService(messenger: registrar.messenger())
      playbackService = QuranPlaybackService(registrar: registrar)
      askService = AskAIService(messenger: registrar.messenger())
      prayerLocationService = PrayerLocationService(messenger: registrar.messenger())
      qiblaCompassService = QiblaCompassService(messenger: registrar.messenger())
      audioService?.onPCM16LE = { [weak coreMLService] pcm in
        coreMLService?.acceptPCM16LE(pcm)
      }
    }
  }
}
