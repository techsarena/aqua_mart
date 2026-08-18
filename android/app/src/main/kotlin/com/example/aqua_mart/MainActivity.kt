package com.example.aqua_mart

import android.net.Uri
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val cnicOcrChannel = "aqua_mart/cnic_ocr"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, cnicOcrChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "recognizeText") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("invalid_path", "The CNIC image is unavailable.", null)
                    return@setMethodCallHandler
                }

                try {
                    val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
                    val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                    val barcodeOptions = BarcodeScannerOptions.Builder()
                        .setBarcodeFormats(
                            Barcode.FORMAT_QR_CODE,
                            Barcode.FORMAT_DATA_MATRIX,
                            Barcode.FORMAT_PDF417,
                            Barcode.FORMAT_AZTEC,
                        )
                        .build()
                    val barcodeScanner = BarcodeScanning.getClient(barcodeOptions)
                    val textTask = recognizer.process(image)
                    val barcodeTask = barcodeScanner.process(image)

                    Tasks.whenAllComplete(textTask, barcodeTask)
                        .addOnCompleteListener {
                            val text = if (textTask.isSuccessful) textTask.result.text else ""
                            val hasBackBarcode =
                                barcodeTask.isSuccessful && barcodeTask.result.isNotEmpty()

                            // Text recognition is what the SERVER re-checks, and
                            // it only ever sees this string - it cannot see the
                            // barcode. Reporting success with empty text let a
                            // card pass on-device (on barcode evidence alone)
                            // and then be rejected on upload, which is a dead
                            // end for the user. An unreadable card must fail
                            // here, while the model is still on screen.
                            if (!textTask.isSuccessful || text.isBlank()) {
                                val error = textTask.exception
                                result.error(
                                    "ocr_failed",
                                    error?.message
                                        ?: "Could not read any text on this card.",
                                    null,
                                )
                            } else {
                                result.success(
                                    mapOf(
                                        "text" to text,
                                        "hasBackBarcode" to hasBackBarcode,
                                    ),
                                )
                            }
                            recognizer.close()
                            barcodeScanner.close()
                        }
                } catch (error: Exception) {
                    result.error("invalid_image", error.message ?: "Could not open this CNIC image.", null)
                }
            }
    }
}
