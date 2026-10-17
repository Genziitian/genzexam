import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Selects the configured monthly plan, even when Play also returns annual plans.
/// Checkout wording comes from Play's actual phases, not the web plan's price.
class ProPlayOffer {
  const ProPlayOffer(this.product, this.details, {required this.isTrial});

  final GooglePlayProductDetails product;
  final SubscriptionOfferDetailsWrapper details;
  final bool isTrial;

  String get terms {
    final monthlyPrice = details.pricingPhases.last.formattedPrice;
    if (!isTrial) return '$monthlyPrice / month · billed monthly';
    final period = details.pricingPhases.first.billingPeriod;
    final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(period);
    if (match == null) {
      return 'Free trial, then $monthlyPrice / month';
    }
    final count = int.parse(match[1]!);
    final unit = {
      'D': 'day',
      'W': 'week',
      'M': 'month',
      'Y': 'year',
    }[match[2]]!;
    return '$count-$unit free trial, then $monthlyPrice / month';
  }

  static ProPlayOffer? select(
    Iterable<GooglePlayProductDetails> products, {
    required String basePlanId,
    required String? trialOfferId,
    required bool trialAvailable,
  }) {
    ProPlayOffer? regular;
    ProPlayOffer? trial;
    for (final product in products) {
      final index = product.subscriptionIndex;
      final offers = product.productDetails.subscriptionOfferDetails;
      if (index == null ||
          offers == null ||
          index < 0 ||
          index >= offers.length) {
        continue;
      }
      final offer = offers[index];
      if (offer.basePlanId != basePlanId ||
          offer.installmentPlanDetails != null ||
          offer.pricingPhases.isEmpty ||
          offer.pricingPhases.last.billingPeriod != 'P1M' ||
          offer.pricingPhases.last.recurrenceMode !=
              RecurrenceMode.infiniteRecurring) {
        continue;
      }
      if (offer.offerId == null) {
        regular ??= ProPlayOffer(product, offer, isTrial: false);
      } else if (trialAvailable &&
          trialOfferId != null &&
          offer.offerId == trialOfferId &&
          offer.pricingPhases.length > 1 &&
          offer.pricingPhases.first.priceAmountMicros == 0) {
        trial ??= ProPlayOffer(product, offer, isTrial: true);
      }
    }
    return trial ?? regular;
  }
}
