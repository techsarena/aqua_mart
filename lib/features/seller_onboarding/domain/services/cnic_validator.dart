/// Which physical side of a Pakistani CNIC the user is providing.
enum CnicSide { front, back }

/// Result of inspecting OCR text from one side of a CNIC.
class CnicValidationResult {
  const CnicValidationResult._({
    required this.isValid,
    required this.ocrText,
    this.cnicNumber,
    this.message,
    this.hasBarcode = false,
  });

  const CnicValidationResult.valid({
    required String ocrText,
    String? cnicNumber,
    bool hasBarcode = false,
  }) : this._(
         isValid: true,
         ocrText: ocrText,
         cnicNumber: cnicNumber,
         hasBarcode: hasBarcode,
       );

  const CnicValidationResult.invalid(String message, {String ocrText = ''})
    : this._(isValid: false, ocrText: ocrText, message: message);

  final bool isValid;
  final String ocrText;
  final String? cnicNumber;
  final String? message;

  /// Whether a machine-readable code was found on this side. Forwarded to the
  /// server, which cannot see the image and so cannot detect it itself.
  final bool hasBarcode;
}

/// Conservative checks for Pakistani identity-card images.
///
/// OCR cannot establish that a card is genuine or belongs to the person, but
/// it can safely reject unrelated images, unreadable cards, reversed sides,
/// duplicate sides, and two sides carrying different identity numbers.
abstract final class CnicValidator {
  static const _frontSignals = {
    'pakistan',
    'identity',
    'national',
    'name',
    'father',
    'husband',
    'gender',
    'birth',
    'country of stay',
  };

  // These labels belong to the biographical/front face. They deliberately do
  // not include broad words such as "Pakistan" or "identity", which may also
  // be printed on the reverse face.
  static const _frontSideSignals = {
    'name',
    'father',
    'husband',
    'gender',
    'birth',
    'country of stay',
  };

  static const _backSignals = {
    'address',
    'present',
    'current',
    'permanent',
    'issue',
    'expiry',
    'signature',
    'family',
    'nadra',
    'return',
    'serial',
    'issuing authority',
    'qr',
  };

  // Strong reverse-face labels. One of these is enough because phone OCR
  // often reads only one English line among the Urdu address text.
  static const _backSideSignals = {
    'present address',
    'current address',
    'permanent address',
    'card serial',
    'serial no',
    'serial number',
    'family no',
    'family number',
    'issuing authority',
    'qr code',
    'machine readable',
    'visa free entry',
  };

  static CnicValidationResult validateSide(
    String rawText,
    CnicSide side, {
    bool hasBackBarcode = false,
  }) {
    final text = _normalise(rawText);
    final frontScore = _score(text, _frontSignals);
    final frontSideScore = _score(text, _frontSideSignals);
    final backScore = _score(text, _backSignals);
    final backSideScore = _score(text, _backSideSignals);
    final hasStrongBackEvidence = backSideScore >= 1 || hasBackBarcode;

    // A barcode is strong evidence of the reverse face on its own: an
    // Urdu-only card often yields just a few Latin characters, and the
    // machine-readable code is the only thing a phone reliably reads. This
    // check is now the ONLY one — the server no longer re-reads the card —
    // so it must not reject a card it can positively identify.
    if (text.length < 20 &&
        !(side == CnicSide.back && hasStrongBackEvidence && text.length >= 8)) {
      return const CnicValidationResult.invalid(
        'We could not read this card. Retake it in good light and keep all four corners visible.',
      );
    }

    final number = extractNumber(rawText);

    if (side == CnicSide.front) {
      if (backScore >= 2 && frontScore < 2) {
        return CnicValidationResult.invalid(
          'This looks like the back of the CNIC. Add the front side here.',
          ocrText: rawText,
        );
      }
      if (number == null || frontScore < 2) {
        return CnicValidationResult.invalid(
          'This does not look like a readable Pakistani CNIC front. Retake the correct card.',
          ocrText: rawText,
        );
      }
    } else {
      // A real CNIC front also contains issue/expiry dates, a signature, and
      // sometimes NADRA text. Those words previously raised backScore enough
      // to let the front face pass as the back. Front-only biographical labels
      // take precedence regardless of those shared labels.
      if (frontSideScore >= 1) {
        return CnicValidationResult.invalid(
          'This is the front side of the CNIC. Please take or upload a picture of the back side.',
          ocrText: rawText,
        );
      }
      if (!hasStrongBackEvidence && backScore < 2) {
        return CnicValidationResult.invalid(
          'This does not look like a readable Pakistani CNIC back. Retake the correct card.',
          ocrText: rawText,
        );
      }
    }

    return CnicValidationResult.valid(
      ocrText: rawText.trim(),
      cnicNumber: number,
      hasBarcode: hasBackBarcode,
    );
  }

  static String? pairError(
    CnicValidationResult front,
    CnicValidationResult back,
  ) {
    final frontNumber = front.cnicNumber;
    final backNumber = back.cnicNumber;
    if (frontNumber != null &&
        backNumber != null &&
        frontNumber != backNumber) {
      return 'The CNIC front and back appear to be from different cards.';
    }

    final frontText = _normalise(front.ocrText);
    final backText = _normalise(back.ocrText);
    if (frontText.isNotEmpty && frontText == backText) {
      return 'The same CNIC side was selected twice. Add the other side.';
    }
    return null;
  }

  static String? extractNumber(String text) {
    final formatted = RegExp(
      r'(^|\D)(\d{5})[\s\-–—]*(\d{7})[\s\-–—]*(\d)(\D|$)',
      multiLine: true,
    ).firstMatch(text);
    if (formatted != null) {
      return '${formatted.group(2)}${formatted.group(3)}${formatted.group(4)}';
    }

    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final digits = line.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 13) return digits;
    }
    return null;
  }

  static int _score(String text, Set<String> signals) =>
      signals.where(text.contains).length;

  static String _normalise(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
