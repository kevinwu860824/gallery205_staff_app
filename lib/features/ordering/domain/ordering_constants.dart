// lib/features/ordering/domain/input_constants.dart
// Using 'input' might be wrong naming, let's just say constants.dart in domain
// But for now, let's put it in ordering_constants.dart

class OrderingConstants {
  // Order Item Status
  static const String itemStatusSubmitted = 'submitted';
  static const String itemStatusCancelled = 'cancelled';
  
  // Order Group Status (Strings matching DB, though we have Enum)
  static const String orderStatusDining = 'dining';
  static const String orderStatusCompleted = 'completed';
  static const String orderStatusCancelled = 'cancelled';
  static const String orderStatusMerged = 'merged';

  // Printer Prefix
  static const String reprintPrefix = '補 ';
}
