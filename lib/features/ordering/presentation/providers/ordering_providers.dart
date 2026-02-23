import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gallery205_staff_app/core/services/kitchen_ticket_service.dart';
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:gallery205_staff_app/features/ordering/data/datasources/ordering_remote_data_source.dart';
import 'package:gallery205_staff_app/features/ordering/data/repositories/ordering_repository_impl.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/menu.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';
import 'package:gallery205_staff_app/features/ordering/domain/repositories/ordering_repository.dart';
import 'package:gallery205_staff_app/features/ordering/domain/repositories/session_repository.dart'; // NEW
import 'package:gallery205_staff_app/core/events/order_events.dart';
import 'package:gallery205_staff_app/core/services/invoice_service.dart';
import 'package:gallery205_staff_app/core/services/printer_service.dart';
import 'package:gallery205_staff_app/features/inventory/presentation/providers/inventory_providers.dart' hide supabaseClientProvider; // NEW & Hide conflict
// --- Data Layer Providers ---

final orderingRemoteDataSourceProvider = Provider<OrderingRemoteDataSource>((ref) {
  return OrderingRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});

// Event Bus (Singleton)
final orderEventBusProvider = Provider<OrderEventBus>((ref) {
  final bus = OrderEventBus();
  ref.onDispose(() => bus.dispose());
  return bus;
});



// Kitchen Ticket Service (Singleton, Lazy)
final kitchenTicketServiceProvider = Provider<KitchenTicketService>((ref) {
  final service = KitchenTicketServiceImpl(
    remoteDataSource: ref.watch(orderingRemoteDataSourceProvider),
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    printerService: PrinterService(), 
    orderingRepository: ref.watch(orderingRepositoryProvider),
  );
  
  // Subscribe to Bus
  final bus = ref.watch(orderEventBusProvider);
  final sub = bus.stream.listen((event) {
     if (event is OrderSubmittedEvent) {
         service.onOrderSubmitted(event);
     }
  });
  
  ref.onDispose(() => sub.cancel());
  
  return service;
});

// Invoice Service (Singleton, Lazy)
final invoiceServiceProvider = Provider<InvoiceService>((ref) {
  return InvoiceServiceImpl();
});



final orderingRepositoryProvider = Provider<OrderingRepository>((ref) {
  return OrderingRepositoryImpl(
    ref.watch(orderingRemoteDataSourceProvider),
    ref.watch(sharedPreferencesProvider),
    ref.watch(orderEventBusProvider), // Inject Bus
    ref.watch(inventoryRepositoryProvider), // Inject Inventory Repo
  );
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return ref.watch(orderingRepositoryProvider) as SessionRepository;
});

// --- Domain/State Providers ---

// 1. Menu Provider
final menuProvider = FutureProvider.autoDispose<({List<MenuCategory> categories, List<MenuItem> items})>((ref) async {
  final repo = ref.watch(orderingRepositoryProvider);
  return repo.getMenu();
});

// Helper to filter items by category
final categoryItemsProvider = Provider.family<List<MenuItem>, String>((ref, categoryId) {
  final menuAsync = ref.watch(menuProvider);
  return menuAsync.when(
    data: (menu) => menu.items.where((i) => i.categoryId == categoryId).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// 2. Cart Notifier
class CartNotifier extends StateNotifier<List<OrderItem>> {
  CartNotifier() : super([]);

  void addToCart(OrderItem item) {
    state = [...state, item];
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < state.length) {
      final newState = [...state];
      newState.removeAt(index);
      state = newState;
    }
  }

  void clearCart() {
    state = [];
  }
  
  double get totalPrice => state.fold(0.0, (sum, item) => sum + item.totalPrice);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<OrderItem>>((ref) {
  return CartNotifier();
});

// 3. Order Submission Controller
class OrderSubmissionController extends StateNotifier<AsyncValue<void>> {
  final OrderingRepository _repository;

  OrderSubmissionController(this._repository) : super(const AsyncValue.data(null));

  Future<bool> submitOrder({
    required List<OrderItem> items,
    required List<String> tableNumbers,
    String? orderGroupId,
    bool isNewOrder = true,
    String? staffName,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.submitOrder(
        items: items,
        tableNumbers: tableNumbers,
        orderGroupId: orderGroupId,
        isNewOrder: isNewOrder,
        staffName: staffName,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final orderSubmissionControllerProvider = StateNotifierProvider<OrderSubmissionController, AsyncValue<void>>((ref) {
  return OrderSubmissionController(ref.watch(orderingRepositoryProvider));
});
