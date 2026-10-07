import 'api_client.dart';
import 'api_exceptions.dart';
import 'models/storefront_model.dart';

class StorefrontService {
  final ApiClient _client;

  StorefrontService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  /// Fetch all active & approved past papers available in the storefront catalog.
  Future<List<StorefrontPaper>> getPapers() async {
    try {
      final response = await _client.get('/storefront/papers');
      final data = response.data;
      if (data is Map<String, dynamic> && data['papers'] is List) {
        return (data['papers'] as List)
            .map((e) => StorefrontPaper.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Fetch student's purchased or claimed papers, and attempted papers.
  Future<List<MyPaperItem>> getMyPapers() async {
    try {
      final response = await _client.get('/storefront/my-papers');
      final data = response.data;
      if (data is Map<String, dynamic> && data['papers'] is List) {
        return (data['papers'] as List)
            .map((e) => MyPaperItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// One-tap claim for free papers.
  Future<bool> claimFree(int quizId) async {
    try {
      final response = await _client.post('/storefront/papers/$quizId/claim');
      return response.data?['entitled'] == true;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Create Razorpay checkout order for a paid paper.
  Future<StorefrontOrderResponse> createOrder(int quizId) async {
    try {
      final response = await _client.post('/storefront/papers/$quizId/orders');
      return StorefrontOrderResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Verify Razorpay payment signature.
  Future<bool> verifyPayment({
    required int orderId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    try {
      final response = await _client.post(
        '/storefront/payments/verify',
        data: {
          'order_id': orderId,
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_order_id': razorpayOrderId,
          'razorpay_signature': razorpaySignature,
        },
      );
      return response.data?['status'] == 'paid' || response.data?['success'] == true;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
