enum PrintTaskStatus { pending, success, failed }

class PrintTask {
  final String id;
  final String? orderGroupId;
  final Map<String, dynamic> content; // 儲存列印內容的 JSON
  final String printerIp;
  PrintTaskStatus status;
  String? errorMessage;
  final DateTime createdAt;

  PrintTask({
    required this.id,
    this.orderGroupId,
    required this.content,
    required this.printerIp,
    this.status = PrintTaskStatus.pending,
    this.errorMessage,
    required this.createdAt,
  });
}