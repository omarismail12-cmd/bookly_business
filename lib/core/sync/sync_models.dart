class SyncOperation {
  final String operationId, entity, entityId, operation;
  final Map<String, dynamic> payload;
  int retryCount;
  String status;

  /// Free-form context for the current [status]: the error message while
  /// `failed`, or the server's current row (JSON) while `conflict` — never
  /// populated while `pending`/`synced`.
  String? detail;

  SyncOperation({
    required this.operationId,
    required this.entity,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.retryCount = 0,
    this.status = "pending",
    this.detail,
  });
}
