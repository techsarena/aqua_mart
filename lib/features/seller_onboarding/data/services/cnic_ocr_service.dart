import 'dart:io';

import 'package:flutter/services.dart';

/// Bridges to Android ML Kit and iOS Vision for private on-device OCR.
/// The image stays on the device until it has passed CNIC validation.
class CnicOcrService {
  const CnicOcrService();

  static const _channel = MethodChannel('aqua_mart/cnic_ocr');

  Future<CnicOcrResult> recognise(File image) async {
    final payload = await _channel.invokeMethod<Object?>('recognizeText', {
      'path': image.path,
    });
    // Accept the former String response as a compatibility fallback while a
    // hot-running native shell is being restarted after this update.
    if (payload is String) return CnicOcrResult(text: payload);
    if (payload is Map) {
      return CnicOcrResult(
        text: payload['text'] as String? ?? '',
        hasBackBarcode: payload['hasBackBarcode'] as bool? ?? false,
      );
    }
    return const CnicOcrResult(text: '');
  }
}

class CnicOcrResult {
  const CnicOcrResult({required this.text, this.hasBackBarcode = false});

  final String text;
  final bool hasBackBarcode;
}
