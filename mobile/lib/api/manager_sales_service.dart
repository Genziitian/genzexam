import 'api_client.dart';
import 'api_exceptions.dart';
import 'models/manager_sales_model.dart';

class ManagerSalesService {
  final ApiClient _client;

  ManagerSalesService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  /// Fetch sales analytics summary for Manager: totals, 14-day trend, and paper sales breakdown.
  Future<ManagerSalesSummary> getSalesSummary() async {
    try {
      final response = await _client.get('/manager/sales/summary');
      return ManagerSalesSummary.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Fetch customer purchases and orders.
  Future<List<ManagerPurchaseOrder>> getPurchases({int page = 1}) async {
    try {
      final response = await _client.get('/manager/purchases', queryParameters: {'page': page});
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        return (data['data'] as List)
            .map((e) => ManagerPurchaseOrder.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Toggle publication/active state of a paper in the manager workspace.
  Future<bool> setPaperActive(int id, bool isActive) async {
    try {
      final response = await _client.patch('/manager/papers/$id/active', data: {'is_active': isActive});
      return response.data != null;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Update paper pricing (in paise).
  Future<bool> updatePrice(int quizId, int pricePaise) async {
    try {
      final response = await _client.patch(
        '/manager/papers/$quizId/price',
        data: {'price_paise': pricePaise},
      );
      return response.data != null;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
