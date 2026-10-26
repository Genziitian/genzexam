import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'models/storefront_model.dart';
import 'storefront_service.dart';

/// Buys a paid paper with Google Play Billing. Whole-rupee prices map to the
/// one-time product `paper_<rupees>` (for example paper_49); the server checks
/// the purchase with Google before it grants access.
class PaperPlayPurchase {
  static String? productIdFor(StorefrontPaper paper) {
    final price = paper.pricePaise;
    return price >= 100 && price % 100 == 0 ? 'paper_${price ~/ 100}' : null;
  }

  /// True when access was granted, false when the student cancelled.
  static Future<bool> buy(
    StorefrontPaper paper,
    StorefrontService service,
  ) async {
    final productId = productIdFor(paper);
    if (productId == null) {
      throw 'This paper cannot be bought in the app yet.';
    }
    final iap = InAppPurchase.instance;
    if (!await iap.isAvailable()) {
      throw 'Google Play billing is not available on this device.';
    }
    final found = await iap.queryProductDetails({productId});
    if (found.productDetails.isEmpty) {
      throw 'This paper is not set up in Google Play yet.';
    }

    final done = Completer<bool>();
    late final StreamSubscription<List<PurchaseDetails>> sub;
    sub = iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.productID != productId || done.isCompleted) continue;
        if (purchase.status == PurchaseStatus.pending) continue;
        if (purchase.status == PurchaseStatus.error ||
            purchase.status == PurchaseStatus.canceled) {
          if (purchase.pendingCompletePurchase) {
            await iap.completePurchase(purchase);
          }
          if (purchase.status == PurchaseStatus.error) {
            done.completeError(purchase.error?.message ?? 'Purchase failed.');
          } else {
            done.complete(false);
          }
          continue;
        }
        try {
          await service.verifyGooglePlay(
            quizId: paper.id,
            purchaseToken: purchase.verificationData.serverVerificationData,
            productId: productId,
          );
          if (purchase.pendingCompletePurchase) {
            await iap.completePurchase(purchase);
          }
          done.complete(true);
        } catch (error) {
          done.completeError(error);
        }
      }
    });

    try {
      final started = await iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: found.productDetails.first),
        autoConsume: false, // the server consumes after granting access
      );
      if (!started) throw 'Google Play could not start checkout.';
      return await done.future.timeout(const Duration(minutes: 5));
    } finally {
      await sub.cancel();
    }
  }
}
