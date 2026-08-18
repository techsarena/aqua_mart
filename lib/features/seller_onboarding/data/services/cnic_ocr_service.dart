import 'dart:io';

import 'package:flutter/services.dart';

/// Bridges to Android ML Kit and iOS Vision for private on-device OCR.
/// The image stays on the device until it has passed CNIC validation.
class CnicOcrService {
  const CnicOcrService();

  static const _channel = MethodChannel('aqua_mart/cnic_ocr');

  Future<String> recognise(File image) async {
    final text = await _channel.invokeMethod<String>('recognizeText', {
      'path': image.path,
    });
    return text ?? '';
  }
}
