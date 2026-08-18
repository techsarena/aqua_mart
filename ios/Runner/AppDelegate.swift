import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "aqua_mart/cnic_ocr",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "recognizeText" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String,
          let image = UIImage(contentsOfFile: path)?.cgImage
        else {
          result(FlutterError(
            code: "invalid_image",
            message: "Could not open this CNIC image.",
            details: nil
          ))
          return
        }

        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        textRequest.recognitionLanguages = ["en-US"]

        let barcodeRequest = VNDetectBarcodesRequest()
        barcodeRequest.symbologies = [.qr, .dataMatrix, .pdf417, .aztec]

        DispatchQueue.global(qos: .userInitiated).async {
          do {
            try VNImageRequestHandler(cgImage: image).perform([
              textRequest,
              barcodeRequest,
            ])
            let text = textRequest.results?
              .compactMap { $0.topCandidates(1).first?.string }
              .joined(separator: "\n") ?? ""
            let hasBackBarcode = !(barcodeRequest.results?.isEmpty ?? true)
            DispatchQueue.main.async {
              result([
                "text": text,
                "hasBackBarcode": hasBackBarcode,
              ])
            }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(
                code: "ocr_failed",
                message: error.localizedDescription,
                details: nil
              ))
            }
          }
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
