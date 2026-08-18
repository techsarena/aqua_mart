/// Which physical side of a Pakistani CNIC the user is providing.
enum CnicSide { front, back }

/// Result of inspecting OCR text from one side of a CNIC.
class CnicValidationResult {
  const CnicValidationResult._({
    required this.isValid,
    required this.ocrText,
    this.cnicNumber,
    this.message,
  });

  const CnicValidationResult.valid({
    required String ocrText,
    String? cnicNumber,
  }) : this._(isValid: true, ocrText: ocrText, cnicNumber: cnicNumber);

  const CnicValidationResult.invalid(String message, {String ocrText = ''})
    : this._(isValid: false, ocrText: ocrText, message: message);

  final bool isValid;
  final String ocrText;
  final String? cnicNumber;
  final String? message;
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

  static const _backSignals = {
    'address',
    'permanent',
    'issue',
    'expiry',
    'signature',
    'family',
    'nadra',
    'return',
  };

  static CnicValidationResult validateSide(String rawText, CnicSide side) {
    final text = _normalise(rawText);
    if (text.length < 20) {
      return const CnicValidationResult.invalid(
        'We could not read this card. Retake it in good light and keep all four corners visible.',
      );
    }

    final frontScore = _score(text, _frontSignals);
    final backScore = _score(text, _backSignals);
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
      if (frontScore >= 3 && backScore < 2) {
        return CnicValidationResult.invalid(
          'This looks like the front of the CNIC. Add the back side here.',
          ocrText: rawText,
        );
      }
      if (backScore < 2) {
        return CnicValidationResult.invalid(
          'This does not look like a readable Pakistani CNIC back. Retake the correct card.',
          ocrText: rawText,
        );
      }
    }

    return CnicValidationResult.valid(
      ocrText: rawText.trim(),
      cnicNumber: number,
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
