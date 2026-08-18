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

        let request = VNRecognizeTextRequest { request, error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(
                code: "ocr_failed",
                message: error.localizedDescription,
                details: nil
              ))
              return
            }
            let text = (request.results as? [VNRecognizedTextObservation])?
              .compactMap { $0.topCandidates(1).first?.string }
              .joined(separator: "\n") ?? ""
            result(text)
          }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        DispatchQueue.global(qos: .userInitiated).async {
          do {
            try VNImageRequestHandler(cgImage: image).perform([request])
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
