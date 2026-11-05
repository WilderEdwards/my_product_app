import 'package:flutter_test/flutter_test.dart';
import 'package:my_product_app/product_page.dart';

void main() {
  test('search is a case-insensitive substring match', () {
    expect(
      productMatchesFilters(name: 'Cedar Mug', price: 12.5, query: 'cEdAr'),
      isTrue,
    );
    expect(
      productMatchesFilters(name: 'Cedar Mug', price: 12.5, query: 'tea'),
      isFalse,
    );
  });

  test('price bounds are inclusive and combine with search', () {
    expect(
      productMatchesFilters(
        name: 'Harvest Tea',
        price: 18,
        query: 'tea',
        minPrice: 12.5,
        maxPrice: 20,
      ),
      isTrue,
    );
    expect(
      productMatchesFilters(
        name: 'Cedar Mug',
        price: 12.5,
        query: '',
        minPrice: 12.5,
        maxPrice: 12.5,
      ),
      isTrue,
    );
    expect(
      productMatchesFilters(
        name: 'Autumn Sample',
        price: 0,
        query: '',
        maxPrice: 12.5,
      ),
      isTrue,
    );
  });

  test('invalid price bounds are rejected', () {
    expect(priceRangeError('abc', ''), isNotNull);
    expect(priceRangeError('', '-1'), isNotNull);
    expect(priceRangeError('NaN', ''), isNotNull);
    expect(priceRangeError('Infinity', ''), isNotNull);
    expect(priceRangeError('20', '10'), isNotNull);
    expect(priceRangeError('', ''), isNull);
    expect(priceRangeError('12.50', '12.50'), isNull);
  });
}
