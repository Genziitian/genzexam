import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../api/api_client.dart';

/// Google Play purchase UI. The server validates every purchase token before it
/// grants access, so the client never unlocks Pro based on a local response.
class ProMembershipCard extends StatefulWidget {
  const ProMembershipCard({super.key, required this.apiClient});
  final ApiClient apiClient;

  @override
  State<ProMembershipCard> createState() => _ProMembershipCardState();
}

class _ProMembershipCardState extends State<ProMembershipCard> {
  static const _productId = 'quiz_lab_pro_monthly';
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Map<String, dynamic> _membership = {};
  GooglePlayProductDetails? _product;
  bool _trialOfferSelected = false;
  String? _error;
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
    _load();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final response = await widget.apiClient.get<Map<String, dynamic>>(
        '/membership',
      );
      _membership = response.data ?? {};
      final paymentSetup = _membership['payment_setup'] is Map
          ? Map<String, dynamic>.from(_membership['payment_setup'] as Map)
          : <String, dynamic>{};
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          _membership['is_pro'] != true) {
        if (paymentSetup['google_play'] != true) {
          _product = null;
          _error =
              'Google Play billing is still being connected. Please try again later.';
          return;
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
          final trialAvailable = _membership['trial_available'] == true;
          final trialOfferId = _membership['google_play_trial_offer_id']
              ?.toString();
          GooglePlayProductDetails? trialProduct;
          GooglePlayProductDetails? regularProduct;
          for (final product in matching) {
            final index = product.subscriptionIndex;
            final offers = product.productDetails.subscriptionOfferDetails;
            final offer =
                index != null && index >= 0 && index < (offers?.length ?? 0)
                ? offers![index]
                : null;
            if (trialOfferId != null && offer?.offerId == trialOfferId)
              trialProduct ??= product;
            if (offer?.offerId == null) regularProduct ??= product;
          }
          _trialOfferSelected = trialAvailable && trialProduct != null;
          _product = _trialOfferSelected ? trialProduct : regularProduct;
          if (products.error != null) _error = products.error!.message;
          if (products.notFoundIDs.isNotEmpty)
            _error =
                'Pro is not available in Google Play yet. Please try again later.';
        } else {
          _error = 'Google Play billing is unavailable on this device.';
        }
      }
    } catch (error) {
      _error = 'Membership details could not load: $error';
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
        } catch (error) {
          _setMessage(
            'Google Play received the purchase, but server verification did not finish. Tap Restore purchases or contact support before trying to buy again. $error',
            isError: true,
          );
        } finally {
          if (mounted) setState(() => _buying = false);
        }
      }
    }
  }

  Future<void> _buy() async {
    final product = _product;
    if (product == null || _buying) return;
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

  @override
  Widget build(BuildContext context) {
    final subscription = _membership['subscription'] is Map
        ? Map<String, dynamic>.from(_membership['subscription'] as Map)
        : <String, dynamic>{};
    final isPro = _membership['is_pro'] == true;
    final trial = subscription['status'] == 'trialing';
    final plan = _membership['plan'] is Map
        ? Map<String, dynamic>.from(_membership['plan'] as Map)
        : <String, dynamic>{};
    final price =
        _product?.price ??
        '₹${((plan['price_paise'] ?? 9900) / 100).toStringAsFixed(0)}';
    final trialDays = plan['trial_days'] ?? 7;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E6DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRO MEMBERSHIP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Text(
              'Loading membership…',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          else ...[
            Text(
              isPro
                  ? (trial ? 'Free trial active' : 'Pro active')
                  : 'Unlock Pro',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF14251A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subscription['started_at'] != null
                  ? 'Started ${_date(subscription['started_at'])}${subscription['trial_ends_at'] != null ? ' · Trial ends ${_date(subscription['trial_ends_at'])}' : ''}${subscription['current_period_ends_at'] != null ? ' · Next charge / access end ${_date(subscription['current_period_ends_at'])}' : ''}'
                  : _trialOfferSelected
                  ? '$price / month · $trialDays-day free trial, then billed monthly'
                  : '$price / month · billed monthly',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (!isPro &&
                !kIsWeb &&
                defaultTargetPlatform == TargetPlatform.android) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _product == null || _buying ? null : _buy,
                  child: Text(
                    _buying
                        ? 'Opening Google Play…'
                        : _trialOfferSelected
                        ? 'Start free trial'
                        : 'Subscribe to Pro',
                  ),
                ),
              ),
              TextButton(
                onPressed: _restore,
                child: const Text('Restore purchases'),
              ),
            ],
            if (isPro &&
                subscription['id'] != null &&
                subscription['cancel_at_period_end'] != true) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _cancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel renewal'),
              ),
            ],
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message!,
                style: TextStyle(
                  fontSize: 12,
                  color: _error == null
                      ? const Color(0xFF15803D)
                      : const Color(0xFFB91C1C),
                ),
              ),
            ),
          if (_error != null && _message == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
              ),
            ),
        ],
      ),
    );
  }
}
