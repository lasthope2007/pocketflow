import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/main.dart';

void main() {
  test('formats Toman amounts with grouped digits', () {
    expect(formatMoney(1234567), '1,234,567');
  });

  test('formats zero balance', () {
    expect(formatMoney(0), '0');
  });
}
