import 'package:flutter_test/flutter_test.dart';
import 'package:controlmiles/services/odometer_ocr_service.dart';

void main() {
  group('candidateDigits', () {
    test('plain, comma and space grouped odometers', () {
      expect(OdometerOcrService.candidateDigits('87324'), ['87324']);
      expect(OdometerOcrService.candidateDigits('87,324'), ['87324']);
      expect(OdometerOcrService.candidateDigits('87 324 mi'), ['87324']);
    });

    test('a trip meter with one decimal is ignored', () {
      expect(OdometerOcrService.candidateDigits('123.4'), isEmpty);
      expect(OdometerOcrService.candidateDigits('TRIP 456.7 km'), isEmpty);
    });

    test('an odometer that shows tenths is kept', () {
      expect(OdometerOcrService.candidateDigits('87324.5'), ['87324']);
    });

    test('letters read for digits are fixed only next to real digits', () {
      expect(OdometerOcrService.candidateDigits('8O324'), ['80324']);
      expect(OdometerOcrService.candidateDigits('12l45'), ['12145']);
      expect(OdometerOcrService.candidateDigits('OIL FILTER'), isEmpty);
    });
  });

  group('priorFactor', () {
    test('no floor known is neutral', () {
      expect(OdometerOcrService.priorFactor(50000, null), 1.0);
    });

    test('below the last known odometer is unlikely', () {
      expect(OdometerOcrService.priorFactor(80000, 87000), lessThan(1.0));
    });

    test('a plausible gain above the floor is favoured', () {
      expect(OdometerOcrService.priorFactor(87500, 87000), greaterThan(1.0));
    });

    test('a huge jump is neutral', () {
      expect(OdometerOcrService.priorFactor(987000, 87000), 1.0);
    });
  });
}
