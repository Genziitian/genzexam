import 'package:flutter/material.dart';

import '../../api/api_client.dart';

class MembershipHistoryScreen extends StatefulWidget {
  const MembershipHistoryScreen({super.key, required this.apiClient});
  final ApiClient apiClient;
  @override
  State<MembershipHistoryScreen> createState() =>
      _MembershipHistoryScreenState();
}

class _MembershipHistoryScreenState extends State<MembershipHistoryScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _error;
  int _page = 1;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.apiClient.get<Map<String, dynamic>>(
        '/membership/history?page=$_page',
      );
      if (mounted) setState(() => _data = response.data ?? {});
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not load your history. Please retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '')
          ?.toLocal()
          .toString()
          .split('.')
          .first ??
      '—';
  String _amount(Map row) {
    if (row['amount_major'] != null)
      return '${row['currency'] ?? 'INR'} ${row['amount_major']}';
    final minor = row['amount_paise'] ?? row['amount_minor'];
    if (minor == null) return 'Amount unavailable';
    return '${row['currency'] ?? 'INR'} ${((num.tryParse('$minor') ?? 0) / 100).toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final ledger = _data['transactions'] is Map
        ? _data['transactions'] as Map
        : {};
    final rows = ledger['data'] is List ? ledger['data'] as List : [];
    final subscriptions =
        (_data['subscriptions'] ?? _data['memberships']) as List? ?? [];
    final user = _data['user'] is Map ? _data['user'] as Map : {};
    return Scaffold(
      appBar: AppBar(title: const Text('Membership & transactions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: TextButton(onPressed: _load, child: Text(_error!)),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    user['name']?.toString() ?? 'Your account',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(user['email']?.toString() ?? ''),
                  const SizedBox(height: 20),
                  Text(
                    'Membership details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (subscriptions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No membership history yet.'),
                    ),
                  ...subscriptions.whereType<Map>().map(
                    (row) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row['provider'] ?? 'Membership'} · ${row['status'] ?? ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Started: ${_date(row['started_at'] ?? row['created_at'])}',
                            ),
                            if (row['trial_ends_at'] != null)
                              Text(
                                'Trial ends: ${_date(row['trial_ends_at'])}',
                              ),
                            if (row['current_period_ends_at'] != null)
                              Text(
                                '${row['cancel_at_period_end'] == true ? 'Access until' : 'Next charge / access end'}: ${_date(row['current_period_ends_at'])}',
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Transactions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_data['history_note'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('${_data['history_note']}'),
                    ),
                  if (rows.isEmpty) const Text('No recorded transactions.'),
                  ...rows.whereType<Map>().map(
                    (row) => Card(
                      child: ListTile(
                        title: Text(
                          '${row['title'] ?? 'Payment'} · ${_amount(row)}',
                        ),
                        subtitle: Text(
                          '${row['provider'] ?? ''} · ${row['status'] ?? ''}\n${_date(row['paid_at'] ?? row['created_at'])}\nReference: ${row['reference'] ?? '—'}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      Text('Page $_page of ${ledger['last_page'] ?? 1}'),
                      TextButton(
                        onPressed: _page < (ledger['last_page'] as int? ?? 1)
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
    );
  }
}
