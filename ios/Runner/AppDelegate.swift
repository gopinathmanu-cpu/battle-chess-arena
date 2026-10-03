import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var notificationChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    UNUserNotificationCenter.current().delegate = self
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "battle_chess_arena/mobile_notifications",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    notificationChannel = channel
    channel.setMethodCallHandler { call, result in
      let center = UNUserNotificationCenter.current()
      switch call.method {
      case "requestPermission":
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
          DispatchQueue.main.async { result(granted) }
        }
      case "show", "schedule":
        guard
          let arguments = call.arguments as? [String: Any],
          let id = arguments["id"] as? String,
          let title = arguments["title"] as? String,
          let body = arguments["body"] as? String
        else {
          result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
          return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var trigger: UNNotificationTrigger?
        if call.method == "schedule", let at = arguments["at"] as? NSNumber {
          let interval = max(1, at.doubleValue / 1000 - Date().timeIntervalSince1970)
          trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        }
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(code: "notification_failed", message: error.localizedDescription, details: nil))
            } else {
              result(nil)
            }
          }
        }
      case "cancel":
        let id = (call.arguments as? [String: Any])?["id"] as? String ?? "online"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
        result(nil)
      case "cancelAll":
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .sound])
  }
}
