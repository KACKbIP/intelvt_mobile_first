import UIKit
import Flutter
import PushKit
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        GeneratedPluginRegistrant.register(with: self)

        // 🔔 Регистрируем PushKit (VoIP)
        let registry = PKPushRegistry(queue: .main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - VoIP token

    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate credentials: PKPushCredentials,
        for type: PKPushType
    ) {
        let token = credentials.token.map { String(format: "%02x", $0) }.joined()
        print("✅ VoIP token:", token)

        SwiftFlutterCallkitIncomingPlugin.sharedInstance?
            .setDevicePushTokenVoIP(token)
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didInvalidatePushTokenFor type: PKPushType
    ) {
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?
            .setDevicePushTokenVoIP("")
    }

    // MARK: - Incoming VoIP push

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else {
            completion()
            return
        }

        print("📩 VoIP payload:", payload.dictionaryPayload)

        let id = payload.dictionaryPayload["id"] as? String ?? UUID().uuidString
        let nameCaller = payload.dictionaryPayload["nameCaller"] as? String ?? "Unknown"
        let handle = payload.dictionaryPayload["handle"] as? String ?? ""

        let isVideo = (payload.dictionaryPayload["isVideo"] as? Int ?? 1) == 1

        let data = flutter_callkit_incoming.Data(
            id: id,
            nameCaller: nameCaller,
            handle: handle,
            type: isVideo ? 1 : 0
        )

        var extra = payload.dictionaryPayload["extra"] as? [String: Any] ?? [:]
        extra["callkitId"] = id
        data.extra = extra as NSDictionary

        print("Data responds setIosParams:", data.responds(to: NSSelectorFromString("setIosParams:")))
        print("Data responds setIos:", data.responds(to: NSSelectorFromString("setIos:")))
        // 🚨 ВАЖНО: сначала CallKit
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?
            .showCallkitIncoming(data, fromPushKit: true)

        // 🚨 И ТОЛЬКО ПОТОМ completion
        completion()
    }
}
