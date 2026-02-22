import 'package:gallery205_staff_app/features/ordering/domain/models/table_model.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_context.dart';

abstract class SessionRepository {
  /// Fetches all table areas (Legacy support).
  Future<List<AreaModel>> fetchAreas();

  /// Fetches tables in an area with status (Legacy support).
  Future<List<TableModel>> fetchTablesInArea(String areaId);

  /// Updates the pax count for an order group (Session).
  Future<void> updatePax(String orderGroupId, int newPax);

  /// Clears a table (marks order/session as completed).
  Future<void> clearSession(Map<String, dynamic> tableData, {String? targetGroupId});

  /// Fetches the full order context (Group + Table Info).
  Future<OrderContext?> getSessionContext(String orderGroupId);
  
  /// Merges multiple order groups into a host group.
  Future<void> mergeOrderGroups({
    required String hostGroupId,
    required List<String> targetGroupIds,
  });

  /// Unmerges specific child groups from a host group.
  Future<void> unmergeOrderGroups({
    required String hostGroupId,
    required List<String> targetGroupIds,
  });

  /// Updates table selection for a group (Move Table).
  Future<void> moveTable({
    required String hostGroupId,
    required List<String> oldTables,
    required List<String> newTables,
  });

  /// Fetches IDs of groups merged into the host.
  Future<List<String>> fetchMergedChildGroups(String hostGroupId);

  /// Deletes an order group entirely (used for empty sessions).
  Future<void> deleteOrderGroup(String orderGroupId);
}
