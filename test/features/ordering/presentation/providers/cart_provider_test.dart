import 'package:flutter_test/flutter_test.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';
import 'package:gallery205_staff_app/features/ordering/presentation/providers/ordering_providers.dart';

void main() {
  group('CartNotifier Tests', () {
    late CartNotifier cartNotifier;

    setUp(() {
      cartNotifier = CartNotifier();
    });

    test('Initial state should be empty', () {
      expect(cartNotifier.state, isEmpty);
    });

    test('addToCart should add items to the list', () {
      final item = OrderItem(
        id: '1',
        itemName: 'Pizza',
        price: 100,
        quantity: 1,
        status: 'pending',
        targetPrintCategoryIds: [],
      );

      cartNotifier.addToCart(item);

      expect(cartNotifier.state.length, 1);
      expect(cartNotifier.state.first, item);
      expect(cartNotifier.totalPrice, 100);
    });

    test('addToCart should append items (no merging logic in current impl)', () {
      final item1 = OrderItem(
        id: '1',
        itemName: 'Pizza',
        price: 100,
        quantity: 1,
        status: 'pending',
        targetPrintCategoryIds: [],
      );

      final item2 = OrderItem(
        id: '2', 
        itemName: 'Pizza',
        price: 100,
        quantity: 2,
        status: 'pending',
        targetPrintCategoryIds: [],
      );

      cartNotifier.addToCart(item1);
      cartNotifier.addToCart(item2);

      // Current implementation simply appends
      expect(cartNotifier.state.length, 2);
      expect(cartNotifier.totalPrice, 300); // 100*1 + 100*2 = 300
    });

    test('removeFromCart should remove item at correct index', () {
      final item1 = OrderItem(
        id: '1',
        itemName: 'Pizza',
        price: 100,
        quantity: 1,
        status: 'pending',
        targetPrintCategoryIds: [],
      );
      final item2 = OrderItem(
        id: '2',
        itemName: 'Burger',
        price: 50,
        quantity: 1,
        status: 'pending',
        targetPrintCategoryIds: [],
      );

      cartNotifier.addToCart(item1);
      cartNotifier.addToCart(item2);

      cartNotifier.removeFromCart(0); // Remove Pizza

      expect(cartNotifier.state.length, 1);
      expect(cartNotifier.state.first.itemName, 'Burger');
      expect(cartNotifier.totalPrice, 50);
    });

    test('clearCart should remove all items', () {
      final item = OrderItem(
        id: '1',
        itemName: 'Pizza',
        price: 100,
        quantity: 1,
        status: 'pending',
        targetPrintCategoryIds: [],
      );

      cartNotifier.addToCart(item);
      cartNotifier.clearCart();

      expect(cartNotifier.state, isEmpty);
      expect(cartNotifier.totalPrice, 0);
    });
  });
}
