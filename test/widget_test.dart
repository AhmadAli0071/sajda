import 'package:flutter_test/flutter_test.dart';

import 'package:sajda_dataplus/data/static_data.dart';
import 'package:sajda_dataplus/services/api_client.dart';

void main() {
  test('99 names list has 99 entries', () {
    expect(allahNames.length, 99);
  });

  test('cities list is not empty and has coordinates', () {
    expect(citiesDb.length, greaterThan(10));
    expect(citiesDb.first.lat, isNot(0));
  });

  test('nearestCity returns nearest city', () {
    final city = nearestCity(24.8607, 67.0011);
    expect(city?.name, 'Karachi');
  });

  test('ApiClient exposes base URL', () {
    expect(ApiClient.instance, isNotNull);
  });
}