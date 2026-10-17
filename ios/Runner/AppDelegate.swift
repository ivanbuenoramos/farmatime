import UIKit
import Flutter
import GoogleMaps

// Ciclo de vida UIScene (obligatorio al compilar con el SDK de iOS 27 / Xcode 27):
// el UISceneDelegate es FlutterSceneDelegate (ver UIApplicationSceneManifest en
// Info.plist) y los plugins se registran cuando Flutter crea el engine implícito.
// Guía: https://docs.flutter.dev/release/breaking-changes/uiscenedelegate
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps exige inicializarse aquí, antes de que exista ninguna vista.
    GMSServices.provideAPIKey("AIzaSyC00CKKmwNiEfs0uUDGCrfcYbz51HbuUuE")

    // Notificaciones push: delega los callbacks de UNUserNotificationCenter en
    // el AppDelegate de Flutter para que firebase_messaging reciba el APNs token
    // y muestre banners en primer plano.
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
