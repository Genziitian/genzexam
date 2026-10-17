import 'package:flutter_test/flutter_test.dart';
import 'package:genz_exam_mobile/api/pro_play_offer.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

PricingPhaseWrapper phase(
  String price,
  int micros,
  String period, {
  bool recurring = true,
}) => PricingPhaseWrapper(
  billingCycleCount: recurring ? 0 : 1,
  billingPeriod: period,
  formattedPrice: price,
  priceAmountMicros: micros,
  priceCurrencyCode: 'INR',
  recurrenceMode: recurring
      ? RecurrenceMode.infiniteRecurring
      : RecurrenceMode.finiteRecurring,
);

SubscriptionOfferDetailsWrapper offer(
  String plan,
  String? id,
  List<PricingPhaseWrapper> phases,
) => SubscriptionOfferDetailsWrapper(
  basePlanId: plan,
  offerId: id,
  offerTags: const [],
  offerIdToken: '$plan-${id ?? 'regular'}',
  pricingPhases: phases,
);

void main() {
  final monthly = phase('₹99.00', 99000000, 'P1M');
  final products = GooglePlayProductDetails.fromProductDetails(
    ProductDetailsWrapper(
      description: 'Quiz LAB Pro',
      name: 'Quiz LAB Pro',
      productId: 'quiz_lab_pro_monthly',
      productType: ProductType.subs,
      title: 'Quiz LAB Pro',
      subscriptionOfferDetails: [
        offer('annual', null, [phase('₹999.00', 999000000, 'P1Y')]),
        offer('annual', 'trial-7-days', [
          phase('Free', 0, 'P7D', recurring: false),
          phase('₹999.00', 999000000, 'P1Y'),
        ]),
        offer('monthly', 'trial-7-days', [
          phase('Free', 0, 'P7D', recurring: false),
          monthly,
        ]),
        offer('monthly', null, [monthly]),
      ],
    ),
  );

  test(
    'eligible student gets monthly trial and sees the actual renewal price',
    () {
      final selected = ProPlayOffer.select(
        products,
        basePlanId: 'monthly',
        trialOfferId: 'trial-7-days',
        trialAvailable: true,
      )!;
      expect(selected.product.offerToken, 'monthly-trial-7-days');
      expect(selected.terms, '7-day free trial, then ₹99.00 / month');
    },
  );

  test('a trial used on either platform selects the regular monthly offer', () {
    final selected = ProPlayOffer.select(
      products,
      basePlanId: 'monthly',
      trialOfferId: 'trial-7-days',
      trialAvailable: false,
    )!;
    expect(selected.product.offerToken, 'monthly-regular');
    expect(selected.isTrial, false);
  });

  test(
    'annual-only availability cannot silently become the monthly purchase',
    () {
      expect(
        ProPlayOffer.select(
          products.take(2),
          basePlanId: 'monthly',
          trialOfferId: 'trial-7-days',
          trialAvailable: true,
        ),
        isNull,
      );
    },
  );

  test('unavailable trial falls back to the regular plan without promising a trial', () {
    final selected = ProPlayOffer.select(
      products,
      basePlanId: 'monthly',
      trialOfferId: 'not-available',
      trialAvailable: true,
    )!;
    expect(selected.isTrial, false);
    expect(selected.terms, '₹99.00 / month · billed monthly');
  });
  test('yearly uses the annual token and yearly price with no trial', () {
    final selected = ProPlayOffer.select(products, basePlanId: 'annual',
      trialOfferId: null, trialAvailable: false, billingPeriod: 'P1Y')!;
    expect(selected.product.offerToken, 'annual-regular');
    expect(selected.price, '₹999.00');
    expect(selected.terms, '₹999.00 / year · billed yearly');
    expect(selected.isTrial, false);
  });

}
