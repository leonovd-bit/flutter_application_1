import Flutter
import UIKit
import GoogleMaps
import SquareInAppPaymentsSDK

@main
@objc class AppDelegate: FlutterAppDelegate, SQIPCardEntryViewControllerDelegate {
  private let channelName = "freshpunk/square_payments"
  private var cardEntryResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Google Maps with Victus-specific API key
    GMSServices.provideAPIKey("AIzaSyCo8B9rp5xliWRtybccAt-_8YcCuswBMrs")

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        switch call.method {
        case "initialize":
          if let args = call.arguments as? [String: Any],
             let appId = args["applicationId"] as? String, !appId.isEmpty {
            SQIPInAppPaymentsSDK.squareApplicationID = appId
            result(true)
          } else {
            result(FlutterError(code: "INVALID_APP_ID", message: "Square application ID is required", details: nil))
          }
        case "tokenizeCard":
          if self.cardEntryResult != nil {
            result(FlutterError(code: "IN_PROGRESS", message: "Card entry already in progress", details: nil))
            return
          }
          self.cardEntryResult = result
          let cardEntry = SQIPCardEntryViewController()
          cardEntry.delegate = self
          controller.present(cardEntry, animated: true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func cardEntryViewControllerDidCancel(_ cardEntryViewController: SQIPCardEntryViewController) {
    cardEntryViewController.dismiss(animated: true) { [weak self] in
      self?.cardEntryResult?(FlutterError(code: "CANCELED", message: "Card entry canceled", details: nil))
      self?.cardEntryResult = nil
    }
  }

  func cardEntryViewController(
    _ cardEntryViewController: SQIPCardEntryViewController,
    didObtain cardDetails: SQIPCardDetails,
    completionHandler: @escaping (Error?) -> Void
  ) {
    completionHandler(nil)
    cardEntryViewController.dismiss(animated: true) { [weak self] in
      self?.cardEntryResult?(cardDetails.nonce)
      self?.cardEntryResult = nil
    }
  }

  func cardEntryViewController(
    _ cardEntryViewController: SQIPCardEntryViewController,
    didCompleteWith error: Error
  ) {
    cardEntryViewController.dismiss(animated: true) { [weak self] in
      self?.cardEntryResult?(FlutterError(code: "FAILED", message: error.localizedDescription, details: nil))
      self?.cardEntryResult = nil
    }
  }
}
