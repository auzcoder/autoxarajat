import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // Flutter asosiy controller
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController

    // iCloud bilan sinxronlash uchun MethodChannel
    let channel = FlutterMethodChannel(
      name: "icloud_sync",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "saveEntries":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "BAD_ARGS", message: "Arguments expected", details: nil))
          return
        }

        let entriesJson = args["entriesJson"] as? String ?? "[]"
        let updatedAt = args["updatedAt"] as? String ?? ""

        let store = NSUbiquitousKeyValueStore.default
        store.set(entriesJson, forKey: "refuel_entries_json")
        store.set(updatedAt, forKey: "refuel_entries_updated_at")
        store.synchronize()
        result(nil)

      case "loadEntries":
        let store = NSUbiquitousKeyValueStore.default
        let entriesJson = store.string(forKey: "refuel_entries_json") ?? ""
        let updatedAt = store.string(forKey: "refuel_entries_updated_at") ?? ""
        result([
          "entriesJson": entriesJson,
          "updatedAt": updatedAt
        ])

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
