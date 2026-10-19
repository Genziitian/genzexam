import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../widgets/premium_widgets.dart';

class MembershipHistoryScreen extends StatefulWidget {
  const MembershipHistoryScreen({
    super.key,
    required this.apiClient,
    this.onViewPlans,
    this.onRestore,
  });
  final ApiClient apiClient;
  final Future<void> Function()? onViewPlans;
  final Future<void> Function()? onRestore;
  @override
  State<MembershipHistoryScreen> createState() =>
      _MembershipHistoryScreenState();
}

class _MembershipHistoryScreenState extends State<MembershipHistoryScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic> _data = {}, _membership = {};
  bool _loading = true, _busy = false;
  String? _error;
  int _page = 1;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading && !_busy) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final membership = await widget.apiClient.get<Map<String, dynamic>>(
        '/membership',
      );
      final history = await widget.apiClient.get<Map<String, dynamic>>(
        '/membership/history?page=$_page',
      );
      if (mounted)
        setState(() {
          _membership = membership.data ?? {};
          _data = history.data ?? {};
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Could not load membership details. Tap to retry.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return date == null
        ? '—'
        : '${MaterialLocalizations.of(context).formatMediumDate(date)} ${TimeOfDay.fromDateTime(date).format(context)}';
  }

  String _amount(Map row) {
    if (row['amount_major'] != null)
      return '${row['currency'] ?? 'INR'} ${row['amount_major']}';
    final minor = num.tryParse('${row['amount_paise'] ?? row['amount_minor']}');
    if (minor == null) return 'Amount unavailable';
    final code = '${row['currency'] ?? 'INR'}';
    final digits =
        [
          'JPY',
          'KRW',
          'VND',
          'CLP',
          'PYG',
          'RWF',
          'UGX',
          'VUV',
          'XAF',
          'XOF',
          'XPF',
          'BIF',
          'DJF',
          'GNF',
          'KMF',
        ].contains(code)
        ? 0
        : ['BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND'].contains(code)
        ? 3
        : 2;
    final divisor = digits == 0
        ? 1
        : digits == 3
        ? 1000
        : 100;
    return '$code ${(minor / divisor).toStringAsFixed(digits)}';
  }

  Future<void> _manage(Map row, String action) async {
    const details =
        'Stop future renewals? Your existing paid or trial access keeps its end date. This does not issue a refund.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel renewal?'),
        content: Text(details),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await widget.apiClient.post<Map<String, dynamic>>(
        '/membership/manage',
        data: {'subscription_id': row['id'], 'action': action},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.data?['message'] ?? 'Membership updated.'}'),
        ),
      );
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The provider could not confirm this change. Refresh before retrying.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPlay() async {
    final opened = await launchUrl(
      Uri.https('play.google.com', '/store/account/subscriptions', {
        'sku': 'quiz_lab_pro_monthly',
        'package': 'in.genziitian.quizlab',
      }),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open Google Play. Open Play Store → Payments & subscriptions → Subscriptions.',
          ),
        ),
      );
  }

  Widget _subscription(Map row) {
    final status = '${row['status'] ?? ''}';
    final google = row['provider'] == 'google_play';
    final razorpay = row['provider'] == 'razorpay';
    final renewing =
        ['active', 'trialing', 'paused'].contains(status) &&
        row['cancel_at_period_end'] != true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${google
                  ? 'Google Play'
                  : razorpay
                  ? 'Razorpay'
                  : 'Complimentary access'} · $status',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '${status == 'pending' ? 'Checkout started' : 'Subscription started'}: ${_date(row['started_at'] ?? row['created_at'])}',
            ),
            if (row['first_payment_recorded_at'] != null)
              Text(
                'First recorded payment: ${_date(row['first_payment_recorded_at'])}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              )
            else if (row['paid_at'] != null)
              Text('Payment recorded: ${_date(row['paid_at'])}')
            else if (status == 'pending')
              const Text('Purchase not yet confirmed.'),
            if (!google && !razorpay)
              const Text('Complimentary access — no recurring charge.')
            else if (row['next_charge_at'] != null)
              Text(
                'Next expected charge: ${_date(row['next_charge_at'])}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Brand.green,
                ),
              )
            else if ([
                  'cancelled',
                  'expired',
                  'revoked',
                  'paused',
                ].contains(status) ||
                row['cancel_at_period_end'] == true)
              const Text('No next charge is currently scheduled in Quiz LAB.')
            else
              const Text('Next charge date: awaiting provider confirmation.'),
            if (row['trial_ends_at'] != null)
              Text('Trial ends: ${_date(row['trial_ends_at'])}'),
            if (row['current_period_ends_at'] != null)
              Text(
                '${row['cancel_at_period_end'] == true || status == 'cancelled' ? 'Access until' : 'Current period ends'}: ${_date(row['current_period_ends_at'])}',
              ),
            if (row['cancel_at_period_end'] == true)
              const Text(
                'Renewal cancellation scheduled. Any remaining access keeps its end date.',
              ),
            if (google) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _openPlay,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Manage in Google Play'),
              ),
              const Text(
                'Manage renewal, payment methods and eligible resubscription options with Google Play.',
                style: TextStyle(fontSize: 12, color: Brand.muted),
              ),
            ],
            Wrap(
              spacing: 8,
              children: [
                if (renewing)
                  TextButton(
                    onPressed: _busy ? null : () => _manage(row, 'cancel'),
                    child: const Text('Cancel renewal'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledger = _data['transactions'] is Map
        ? _data['transactions'] as Map
        : {};
    final rows = ledger['data'] is List ? ledger['data'] as List : [];
    final subscriptions =
        (_data['subscriptions'] ?? _data['memberships']) as List? ?? [];
    final hasPaused = subscriptions.whereType<Map>().any(
      (row) => row['status'] == 'paused',
    );
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Membership & transactions'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Membership'),
              Tab(text: 'Transactions'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: TextButton(onPressed: _load, child: Text(_error!)),
              )
            : TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _membership['is_pro'] != true && !hasPaused
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 48,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'No membership',
                                    style: TextStyle(
                                      color: Brand.muted,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (widget.onViewPlans != null)
                                    FilledButton(
                                      onPressed: _busy
                                          ? null
                                          : () async {
                                              await widget.onViewPlans!();
                                              await _load();
                                            },
                                      child: const Text('Get membership'),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text(
                                _membership['is_pro'] == true
                                    ? 'Pro access active'
                                    : 'Subscription paused',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _membership['is_pro'] == true
                                          ? Brand.green
                                          : null,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              ...subscriptions.whereType<Map>().map(
                                _subscription,
                              ),
                            ],
                          ),
                  ),
                  RefreshIndicator(
                    onRefresh: _load,
                    child: rows.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 48,
                              ),
                              child: Text(
                                'No transactions',
                                style: TextStyle(
                                  color: Brand.muted,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            children: [
                              ...rows.whereType<Map>().map(
                                (row) => Card(
                                  child: ListTile(
                                    title: Text(
                                      '${row['title'] ?? 'Payment'} · ${_amount(row)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${row['provider'] ?? ''} · ${row['status'] ?? ''}\n${_date(row['paid_at'] ?? row['created_at'])}\nReference: ${row['reference'] ?? '—'}',
                                    ),
                                    isThreeLine: true,
                                  ),
                                ),
                              ),
                              if ((ledger['last_page'] as int? ?? 1) > 1)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton(
                                      onPressed: _page > 1
                                          ? () {
                                              _page--;
                                              _load();
                                            }
                                          : null,
                                      child: const Text('Previous'),
                                    ),
                                    Text(
                                      'Page $_page of ${ledger['last_page']}',
                                    ),
                                    TextButton(
                                      onPressed:
                                          _page <
                                              (ledger['last_page'] as int? ?? 1)
                                          ? () {
                                              _page++;
                                              _load();
                                            }
                                          : null,
                                      child: const Text('Next'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
