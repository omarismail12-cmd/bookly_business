class SyncOperation {
  final String operationId, entity, entityId, operation;
  final Map<String, dynamic> payload;
  int retryCount;
  String status;
  SyncOperation({
    required this.operationId,
    required this.entity,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.retryCount = 0,
    this.status = "pending",
  });
}
