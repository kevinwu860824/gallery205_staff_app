import 'package:gallery205_staff_app/core/events/order_events.dart';
import 'package:gallery205_staff_app/core/services/printer_service.dart';
import 'package:gallery205_staff_app/features/ordering/data/datasources/ordering_remote_data_source.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_context.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';

import 'package:gallery205_staff_app/features/ordering/domain/repositories/ordering_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service responsible for Kitchen/Bar Ticket Printing.
/// Listens to [OrderSubmittedEvent].
abstract class KitchenTicketService {
  void onOrderSubmitted(OrderSubmittedEvent event);
}

class KitchenTicketServiceImpl implements KitchenTicketService {
  final OrderingRemoteDataSource remoteDataSource;
  final SharedPreferences sharedPreferences;
  final PrinterService printerService;
  final OrderingRepository orderingRepository;

  KitchenTicketServiceImpl({
    required this.remoteDataSource,
    required this.sharedPreferences,
    required this.printerService,
    required this.orderingRepository,
  });
  
  String? get _currentShopId => sharedPreferences.getString('savedShopId');

  @override
  Future<void> onOrderSubmitted(OrderSubmittedEvent event) async {
    print("KitchenTicketService: Processing OrderSubmittedEvent for ${event.orderGroupId}");
    
    try {
       final shopId = _currentShopId;
       if (shopId == null) {
          print("KitchenTicketService: No Shop ID, skipping.");
          return;
       }

       // 1. Fetch Settings
       final printerSettings = await remoteDataSource.getPrinterSettings(shopId);
       final allPrintCategories = await remoteDataSource.getPrintCategories(shopId);
       
       int orderSeq = 0;
       try {
          orderSeq = await remoteDataSource.getOrderSequenceNumber(shopId);
       } catch (e) {
          print("KitchenTicketService: Failed to get seq number: $e");
       }
       
       // 2. Construct Context
       final orderGroup = OrderGroup(
          id: event.orderGroupId,
          status: OrderStatus.dining,
          items: event.items,
          shopId: shopId,
       );
       
       final orderContext = OrderContext(
          order: orderGroup,
          tableNames: event.tableNumbers,
          peopleCount: 1,
          staffName: event.staffName ?? '',
       );

       // 3. Process Printing
       final failedItemIds = await printerService.processOrderPrinting(
          orderContext,
          printerSettings,
          allPrintCategories,
          orderSeq
       );

       // 4. Update Status
       if (!event.isOffline) {
          final allItemIds = event.items.map((e) => e.id).toList();
          final successItemIds = allItemIds.where((id) => !failedItemIds.contains(id)).toList();

          if (successItemIds.isNotEmpty) {
             await orderingRepository.updatePrintStatus(successItemIds, 'success');
          }
          if (failedItemIds.isNotEmpty) {
             await orderingRepository.updatePrintStatus(failedItemIds, 'failed');
          }
       }

    } catch (e) {
       print("KitchenTicketService: Error processing order: $e");
    }
  }
}
