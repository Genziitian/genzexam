import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genz_exam_mobile/api/pro_play_offer.dart';
import 'package:genz_exam_mobile/api/api_exceptions.dart';
import 'package:genz_exam_mobile/screens/student/pro_paywall_screen.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'pro_play_offer_test.dart' as fixtures;

void main() {
  testWidgets('blocked membership is not shown as a missing Google Play plan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ProPaywallScreen(
          membershipError: const ApiException(
            message: 'Server blocked this request',
            statusCode: 403,
            isSecurityChallenge: true,
          ),
          onSubscribe: (_) async =>
              fail('A blocked membership must not start a purchase'),
          onRestore: () {},
          onRetry: () => retries++,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Membership unavailable'), findsOneWidget);
    expect(find.text('Choose your plan'), findsNothing);
    expect(find.text('Plan unavailable in Google Play'), findsNothing);
    expect(find.textContaining('ApiException('), findsNothing);
    await tester.ensureVisible(find.text('Try again'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing Play products remain distinct from a membership server error',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProPaywallScreen(
            onSubscribe: (_) async {},
            onRestore: () {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Plan unavailable in Google Play'), findsOneWidget);
      expect(find.text('Membership unavailable'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'selected yearly plan sends annual offer; monthly trial shows its real terms',
    (tester) async {
      final products = GooglePlayProductDetails.fromProductDetails(
        ProductDetailsWrapper(
          description: 'Pro',
          name: 'Pro',
          productId: 'quiz_lab_pro_monthly',
          productType: ProductType.subs,
          title: 'Pro',
          subscriptionOfferDetails: [
            fixtures.offer('monthly', 'trial-7-days', [
              fixtures.phase('Free', 0, 'P7D', recurring: false),
              fixtures.phase('₹99', 99000000, 'P1M'),
            ]),
            fixtures.offer('annual', null, [
              fixtures.phase('₹999', 999000000, 'P1Y'),
            ]),
          ],
        ),
      );
      final monthly = ProPlayOffer.select(
        products,
        basePlanId: 'monthly',
        trialOfferId: 'trial-7-days',
        trialAvailable: true,
      )!;
      final yearly = ProPlayOffer.select(
        products,
        basePlanId: 'annual',
        trialOfferId: null,
        trialAvailable: false,
        billingPeriod: 'P1Y',
      )!;
      ProPlayOffer? purchased;
      await tester.pumpWidget(
        MaterialApp(
          home: ProPaywallScreen(
            monthly: monthly,
            yearly: yearly,
            onSubscribe: (offer) async {
              purchased = offer;
            },
            onRestore: () {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Try for free').evaluate().isEmpty
            ? find.text('Try for free').last
            : find.widgetWithText(ElevatedButton, 'Try for free'),
      );
      await tester.pump();
      expect(purchased?.product.offerToken, 'monthly-trial-7-days');
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Yearly'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('FREE'), findsNothing);
      expect(find.text('Due today'), findsNothing);
      await tester.tap(find.text('Subscribe yearly'));
      await tester.pump();
      expect(purchased?.product.offerToken, 'annual-regular');
      expect(purchased?.isTrial, false);
      expect(tester.takeException(), isNull);
    },
  );
}
