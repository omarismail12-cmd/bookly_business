abstract interface class PdfService {
  Future<List<int>> createReceipt({required Map<String, dynamic> data});
  Future<List<int>> createReport({required Map<String, dynamic> data});
}
