import UIKit
import Flutter
import FirebaseCore
import flutter_local_notifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    FirebaseApp.configure()

    // 🔥 flutter_local_notifications 必須的背景註冊
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    GeneratedPluginRegistrant.register(with: self)

    // ── Widget Session Channel ──
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.caffreywu.tableOrderingApp/widget_session",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      let defaults = UserDefaults(suiteName: "group.com.caffreywu.tableOrderingApp")
      if call.method == "saveSession" {
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "BAD_ARGS", message: "Expected Map", details: nil))
          return
        }
        defaults?.set(args["jwt"]     as? String ?? "", forKey: "supabase_jwt")
        defaults?.set(args["user_id"] as? String ?? "", forKey: "user_id")
        defaults?.set(args["shop_id"] as? String ?? "", forKey: "shop_id")
        defaults?.synchronize()
        WidgetCenter.shared.reloadTimelines(ofKind: "ScheduleWidget")
        result(nil)
      } else if call.method == "clearSession" {
        defaults?.removeObject(forKey: "supabase_jwt")
        defaults?.removeObject(forKey: "user_id")
        defaults?.removeObject(forKey: "shop_id")
        defaults?.synchronize()
        WidgetCenter.shared.reloadTimelines(ofKind: "ScheduleWidget")
        result(nil)
      } else if call.method == "reloadWidget" {
        WidgetCenter.shared.reloadTimelines(ofKind: "ScheduleWidget")
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
