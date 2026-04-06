/// Hub Server 回傳 409 Conflict 時拋出（例如桌位已被入座）
class HubConflictException implements Exception {
  final String error;
  final Map<String, dynamic> data;
  HubConflictException(this.error, this.data);
  @override
  String toString() => 'HubConflictException: $error';
}
