import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../api/api_client.dart';
import '../../api/api_exceptions.dart';
import '../../api/app_icon_service.dart';
import '../../api/pro_play_offer.dart';
import '../../widgets/premium_widgets.dart';
import '../../widgets/status_screen.dart';
import 'pro_paywall_screen.dart';
import 'membership_history_screen.dart';

class ProMembershipScreen extends StatelessWidget {
  const ProMembershipScreen({super.key, required this.apiClient});
  final ApiClient apiClient;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: ProMembershipCard(apiClient: apiClient, fullScreen: true));
}

/// Google Play purchase UI. The server validates every purchase token before it
/// grants access, so the client never unlocks Pro based on a local response.
class ProMembershipCard extends StatefulWidget {
  const ProMembershipCard({
    super.key,
    required this.apiClient,
    this.fullScreen = false,
  });
  final ApiClient apiClient;
  final bool fullScreen;

  @override
  State<ProMembershipCard> createState() => _ProMembershipCardState();
}

class _ProMembershipCardState extends State<ProMembershipCard> {
  static const _productId = 'quiz_lab_pro_monthly';
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Map<String, dynamic> _membership = {};
  GooglePlayProductDetails? _product;
  ProPlayOffer? _playOffer;
  ProPlayOffer? _monthlyOffer;
  ProPlayOffer? _yearlyOffer;
  bool _trialOfferSelected = false;
  bool _billingReady = false;
  final Set<String> _celebratedPurchases = {};
  String? _error;
  Object? _membershipLoadError;
  String? _message;
  bool _loading = true;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) => _setMessage(
        'Google Play purchase could not be completed: $error',
        isError: true,
      ),
    );
    if (widget.fullScreen) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    var membershipLoaded = false;
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
        _membershipLoadError = null;
        _message = null;
        _product = null;
        _playOffer = null;
        _monthlyOffer = null;
        _yearlyOffer = null;
        _trialOfferSelected = false;
        _billingReady = false;
      });
    try {
      final response = await widget.apiClient.get<Map<String, dynamic>>(
        '/membership',
      );
      _membership = response.data ?? {};
      membershipLoaded = true;
      if (_membership['is_pro'] is bool) {
        unawaited(
          AppIconService.syncIcon(isPro: _membership['is_pro'] == true),
        );
      }
      final paymentSetup = _membership['payment_setup'] is Map
          ? Map<String, dynamic>.from(_membership['payment_setup'] as Map)
          : <String, dynamic>{};
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          _membership['is_pro'] != true) {
        _billingReady = paymentSetup['google_play'] == true;
        if (!_billingReady) {
          _error = 'Checkout is temporarily unavailable. Billing verification needs to be configured. You can still view available Google Play prices.';
        }
        final available = await InAppPurchase.instance.isAvailable();
        if (available) {
          final products = await InAppPurchase.instance.queryProductDetails({
            _productId,
          });
          final matching = products.productDetails
              .whereType<GooglePlayProductDetails>()
              .where((product) => product.id == _productId)
              .toList();
          final trialAvailable =
              _membership['trial_available'] == true &&
              ((_membership['plan'] as Map?)?['trial_days'] ?? 7) > 0;
          final configuredTrial = _membership['google_play_trial_offer_id']
              ?.toString()
              .trim();
          final trialOfferId =
              configuredTrial == null || configuredTrial.isEmpty
              ? 'trial-7-days'
              : configuredTrial;
          final basePlanId =
              _membership['google_play_base_plan_id']?.toString() ?? 'monthly';
          _playOffer = ProPlayOffer.select(
            matching,
            basePlanId: basePlanId,
            trialOfferId: trialOfferId,
            trialAvailable: trialAvailable,
          );
          _monthlyOffer = _playOffer;
          _yearlyOffer = ProPlayOffer.select(
            matching,
            basePlanId:
                _membership['google_play_annual_base_plan_id']?.toString() ??
                'annual',
            trialOfferId: null,
            trialAvailable: false,
            billingPeriod: 'P1Y',
          );
          _trialOfferSelected = _playOffer?.isTrial ?? false;
          if (trialAvailable &&
              _monthlyOffer != null &&
              !_trialOfferSelected &&
              _billingReady) {
            _message = 'Google Play has not returned a free-trial offer for this account. The monthly option shown is a paid plan.';
          } else if (!trialAvailable &&
              _monthlyOffer != null &&
              _billingReady) {
            _message = 'A free trial is not available for this Quiz LAB account. Monthly starts with a paid subscription.';
          }
          _product = _playOffer?.product;
          if (products.error != null) _error = products.error!.message;
          if (products.notFoundIDs.isNotEmpty) _error = 'Pro is not available for this Google Play account yet. Install the latest Play testing release and use your tester account.';
          if (products.error == null &&
              _monthlyOffer == null &&
              _yearlyOffer == null &&
              products.notFoundIDs.isEmpty) {
            _error = 'Google Play returned no eligible plans. Check the Play account, test release and regional plan availability.';
          }
        } else {
          _error = 'Google Play billing is unavailable on this device.';
        }
      }
    } catch (error) {
      if (!membershipLoaded) _membershipLoadError = error;
      _error = error is ApiException
          ? error.message
          : 'Membership details could not load. Please try again.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      if (isError) _error = message;
    });
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != _productId) continue;
      if (purchase.status == PurchaseStatus.pending) {
        _setMessage('Waiting for Google Play…');
        continue;
      }
      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        _setMessage(
          purchase.error?.message ?? 'Purchase cancelled.',
          isError: purchase.status == PurchaseStatus.error,
        );
        if (purchase.pendingCompletePurchase)
          await InAppPurchase.instance.completePurchase(purchase);
        if (mounted) setState(() => _buying = false);
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          final token = purchase.verificationData.serverVerificationData;
          await widget.apiClient.post<Map<String, dynamic>>(
            '/membership/google-play/verify',
            data: {'purchase_token': token, 'product_id': purchase.productID},
          );
          if (purchase.pendingCompletePurchase)
            await InAppPurchase.instance.completePurchase(purchase);
          _setMessage(
            'Pro activated. Your purchase is verified with Google Play.',
          );
          await _load();
          final confirmationId = purchase.purchaseID ?? purchase.productID;
          if (mounted &&
              purchase.status == PurchaseStatus.purchased &&
              _membership['is_pro'] == true &&
              _celebratedPurchases.add(confirmationId)) {
            await showStatusScreen(
              context,
              kind: StatusKind.success,
              title: 'Pro activated',
              message: 'Your membership is confirmed. Enjoy your Pro benefits.',
            );
          }
        } catch (error) {
          _setMessage(
            'Google Play received the purchase, but server verification did not finish. Tap Restore purchases or contact support before trying to buy again. $error',
            isError: true,
          );
          if (mounted) {
            await showStatusScreen(
              context,
              kind: StatusKind.failure,
              title: 'Activation not finished',
              message: 'Google Play received your purchase, but we could not confirm it yet. Do not buy again. Tap Restore purchases or contact us.',
              primaryLabel: 'Close',
            );
          }
        } finally {
          if (mounted) setState(() => _buying = false);
        }
      }
    }
  }

  Future<void> _buyOffer(ProPlayOffer offer) async {
    _product = offer.product;
    _playOffer = offer;
    _trialOfferSelected = offer.isTrial;
    await _buy();
  }

  Future<void> _buy() async {
    final product = _product;
    if (product == null || _buying || _planDisabled) return;
    setState(() {
      _buying = true;
      _message = null;
      _error = null;
    });
    try {
      final purchaseParam = GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: product.offerToken,
      );
      final started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!started && mounted)
        setState(() {
          _buying = false;
          _error = 'Google Play could not start checkout. Please try again.';
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _buying = false;
          _error = 'Could not start Google Play checkout: $error';
        });
    }
  }

  Future<void> _restore() async {
    try {
      await InAppPurchase.instance.restorePurchases();
      _setMessage('Checking previous purchases with Google Play…');
    } catch (error) {
      _setMessage('Could not restore purchases: $error', isError: true);
    }
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Pro renewal?'),
        content: const Text(
          'Your Pro access remains until the current trial or billing period ends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Pro'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel renewal'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final response = await widget.apiClient.post<Map<String, dynamic>>(
        '/membership/cancel',
      );
      _setMessage(
        response.data?['message']?.toString() ?? 'Renewal cancelled.',
      );
      await _load();
    } catch (error) {
      _setMessage('Could not cancel renewal: $error', isError: true);
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return date == null ? '—' : '${date.day}/${date.month}/${date.year}';
  }

  bool get _planDisabled =>
      !_billingReady ||
      (_membership['plan'] is Map && _membership['plan']['enabled'] == false);

  @override
  Widget build(BuildContext context) {
    if (!widget.fullScreen)
      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: const Icon(
              Icons.receipt_long_outlined,
              color: Color(0xFF16A34A),
              size: 20,
            ),
            title: const Text(
              'Membership & transactions',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Your plan and payments',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFF94A3B8),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MembershipHistoryScreen(
                  apiClient: widget.apiClient,
                  onRestore: _restore,
                  onViewPlans: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ProMembershipScreen(apiClient: widget.apiClient),
                      ),
                    );
                    if (mounted) await _load();
                  },
                ),
              ),
            ),
          ),
        ),
      );
    final subscription = _membership['subscription'] is Map
        ? Map<String, dynamic>.from(_membership['subscription'] as Map)
        : <String, dynamic>{};
    final isPro = _membership['is_pro'] == true;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!isPro && widget.fullScreen)
      return ProPaywallScreen(
        monthly: _monthlyOffer,
        yearly: _yearlyOffer,
        onSubscribe: _buyOffer,
        onRestore: _restore,
        onRetry: _load,
        disabled: _planDisabled,
        busy: _buying,
        message: _membershipLoadError == null ? _error ?? _message : null,
        membershipError: _membershipLoadError,
      );
    final trial = subscription['status'] == 'trialing';
    final ending =
        subscription['cancel_at_period_end'] == true ||
        subscription['status'] == 'cancelled';
    final canCancel =
        subscription['id'] != null &&
        ['google_play', 'razorpay'].contains(subscription['provider']) &&
        !ending;
    final steps = <(IconData, String, String, bool)>[
      (
        Icons.rocket_launch_rounded,
        'Started',
        _date(subscription['started_at']),
        true,
      ),
      if (trial && subscription['trial_ends_at'] != null)
        (
          Icons.hourglass_bottom_rounded,
          'Free trial ends',
          _date(subscription['trial_ends_at']),
          false,
        ),
      if (subscription['current_period_ends_at'] != null)
        (
          ending ? Icons.event_busy_rounded : Icons.autorenew_rounded,
          ending ? 'Access ends' : 'Next charge',
          _date(subscription['current_period_ends_at']),
          false,
        ),
    ];
    const perks = <(IconData, String)>[
      (Icons.cloud_upload_rounded, 'Turn your own PDF or JSON into tests'),
      (
        Icons.download_for_offline_rounded,
        'Download papers for offline practice',
      ),
      (Icons.play_circle_rounded, 'Video solutions'),
    ];
    const ink = Color(0xFF14251A);
    const muted = Color(0xFF64748B);

    Widget card(Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );

    return Container(
      color: const Color(0xFFF1F5F9),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              8,
              MediaQuery.paddingOf(context).top + 4,
              20,
              28,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F3D26), Color(0xFF16A34A)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.white,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Brand.gold,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFF14251A),
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          ending
                              ? 'RENEWAL OFF'
                              : trial
                              ? 'FREE TRIAL ACTIVE'
                              : 'ACTIVE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Quiz LAB Pro',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ending
                            ? 'You keep Pro until your access ends.'
                            : 'You have full access to every Pro feature.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .85),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              children: [
                if (steps.isNotEmpty)
                  card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your plan timeline',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (var i = 0; i < steps.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == steps.length - 1 ? 0 : 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Brand.green.withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    steps[i].$1,
                                    color: Brand.green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    steps[i].$2,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  steps[i].$3,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'What you get',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final perk in perks)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Icon(perk.$1, color: Brand.green, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  perk.$2,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: ink,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Brand.green,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                card(
                  Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.receipt_long_outlined,
                          color: Brand.green,
                        ),
                        title: const Text(
                          'Membership & transactions',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text('Payments and receipts'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MembershipHistoryScreen(
                              apiClient: widget.apiClient,
                            ),
                          ),
                        ),
                      ),
                      if (canCancel) ...[
                        const Divider(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.cancel_outlined,
                            color: Color(0xFFB91C1C),
                          ),
                          title: const Text(
                            'Cancel renewal',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                          subtitle: const Text(
                            'You keep Pro until the current period ends',
                          ),
                          onTap: _cancel,
                        ),
                      ],
                    ],
                  ),
                ),
                if (_message != null || _error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      (_message ?? _error)!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _error == null
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => openContactUs(context),
                  icon: const Icon(Icons.support_agent_rounded, size: 18),
                  label: const Text('Need help? Contact us'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
