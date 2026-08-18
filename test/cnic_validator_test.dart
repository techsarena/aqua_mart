import 'package:aqua_mart/features/seller_onboarding/domain/services/cnic_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const front = '''
Islamic Republic of Pakistan
National Identity Card
Name Muhammad Saad
Father Name Muhammad Ali
Gender M
Identity Number 35202-1234567-1
Date of Birth 01.01.1995
''';
  const back = '''
Current Address Lahore Punjab
Permanent Address Lahore Punjab
Date of Issue 01.01.2020
Date of Expiry 01.01.2030
Cardholder Signature
NADRA
35202-1234567-1
''';

  test('accepts readable matching CNIC front and back', () {
    final frontResult = CnicValidator.validateSide(front, CnicSide.front);
    final backResult = CnicValidator.validateSide(back, CnicSide.back);

    expect(frontResult.isValid, isTrue);
    expect(backResult.isValid, isTrue);
    expect(CnicValidator.pairError(frontResult, backResult), isNull);
  });

  test('rejects an unrelated image as the CNIC front', () {
    final result = CnicValidator.validateSide(
      'Aqua Mart water delivery receipt total 500 rupees',
      CnicSide.front,
    );

    expect(result.isValid, isFalse);
  });

  test('rejects front photo placed in back slot', () {
    final result = CnicValidator.validateSide(front, CnicSide.back);

    expect(result.isValid, isFalse);
    expect(result.message, contains('front'));
  });

  test('rejects a realistic front even when it contains back signal words', () {
    const frontWithSharedLabels = '''
Islamic Republic of Pakistan
National Identity Card
Name Muhammad Saad
Father Name Muhammad Ali
Gender M
Country of Stay Pakistan
Identity Number 35202-1234567-1
Date of Birth 01.01.1995
Date of Issue 01.01.2020
Date of Expiry 01.01.2030
Cardholder Signature
NADRA
''';

    final result = CnicValidator.validateSide(
      frontWithSharedLabels,
      CnicSide.back,
    );

    expect(result.isValid, isFalse);
    expect(result.message, contains('Please take or upload'));
    expect(result.message, contains('back side'));
  });

  test('accepts a back when OCR reads only one reverse-face label', () {
    final result = CnicValidator.validateSide(
      'Present Address\nHouse 12 Lahore',
      CnicSide.back,
    );

    expect(result.isValid, isTrue);
  });

  test('accepts a sparse back OCR result when its barcode is detected', () {
    final result = CnicValidator.validateSide(
      'PAK 12345',
      CnicSide.back,
      hasBackBarcode: true,
    );

    expect(result.isValid, isTrue);
  });

  test('still rejects unrelated text in the back slot', () {
    final result = CnicValidator.validateSide(
      'Aqua Mart water delivery receipt total 500 rupees',
      CnicSide.back,
    );

    expect(result.isValid, isFalse);
  });

  test('rejects two sides with different CNIC numbers', () {
    final frontResult = CnicValidator.validateSide(front, CnicSide.front);
    final backResult = CnicValidator.validateSide(
      back.replaceFirst('35202-1234567-1', '61101-7654321-9'),
      CnicSide.back,
    );

    expect(
      CnicValidator.pairError(frontResult, backResult),
      contains('different'),
    );
  });
}
