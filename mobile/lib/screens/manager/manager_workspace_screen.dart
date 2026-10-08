import 'package:flutter/material.dart';
import '../../api/api.dart';
import '../../state/auth_state.dart';
import '../../widgets/app_ux_components.dart';
import '../../widgets/confirm_sign_out.dart';
import '../admin/admin_console_screen.dart';

/// Manager Executive Workspace for Manager (Rank 2) users.
/// Executive Dashboard for Revenue, Sales Analytics, Storefront Orders,
/// Paper Catalog Pricing, and User Governance.
class ManagerWorkspaceScreen extends StatefulWidget {
  final AuthState authState;

  const ManagerWorkspaceScreen({super.key, required this.authState});

  @override
  State<ManagerWorkspaceScreen> createState() => _ManagerWorkspaceScreenState();
}

class _ManagerWorkspaceScreenState extends State<ManagerWorkspaceScreen> {
  final ManagerSalesService _salesService = ManagerSalesService();
  bool _isLoading = true;
  ManagerSalesSummary? _summary;
  List<ManagerPurchaseOrder> _orders = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final summary = await _salesService.getSalesSummary();
      final orders = await _salesService.getPurchases();
      if (mounted) {
        setState(() {
          _summary = summary;
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppKeyboardDismiss(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manager Workspace',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Sales, Paper Catalog & Platform Governance',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            // Preview as Student button
            TextButton.icon(
              onPressed: () {
                AppHaptics.light();
                widget.authState.togglePreviewStudentView(true);
              },
              icon: const Icon(Icons.school_outlined, size: 16, color: Color(0xFF38BDF8)),
              label: const Text(
                'Student View',
                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: () {
                AppHaptics.light();
                _loadData();
              },
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              tooltip: 'Refresh Analytics',
            ),
          ],
        ),
        body: SafeArea(
          child: _isLoading
              ? AppShimmerCard.managerWorkspace()
              : _error != null
                  ? AppErrorCard(
                      title: 'Analytics Offline',
                      message: _error!,
                      onRetry: _loadData,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: const Color(0xFF16A34A),
                      child: _buildDashboard(),
                    ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    AppHaptics.light();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminConsoleScreen(authState: widget.authState),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people_outline_rounded, size: 18),
                  label: const Text('Manage User Accounts'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
              onPressed: () {
                AppHaptics.medium();
                confirmSignOut(context, widget.authState);
              },
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                tooltip: 'Sign Out',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final totals = _summary?.totals;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Revenue Headline Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL REVENUE',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  Icon(Icons.currency_rupee_rounded, color: Color(0xFF22C55E), size: 18),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '₹${totals?.revenueRupees ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF334155), height: 1),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statColumn('Today', '₹${totals?.revenueTodayRupees ?? 0}'),
                  _statColumn('7 Days', '₹${totals?.revenue7dRupees ?? 0}'),
                  _statColumn('30 Days', '₹${totals?.revenue30dRupees ?? 0}'),
                  _statColumn('Paid Orders', '${totals?.paidOrders ?? 0}'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Conversion & Paid Papers Metrics
        Row(
          children: [
            Expanded(
              child: _metricBox(
                title: 'Conversion Rate',
                value: '${totals?.conversionPercent ?? 0}%',
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricBox(
                title: 'Active Paid Papers',
                value: '${totals?.paidPapers ?? 0}',
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF10B981),
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // Recent Orders Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Paper Purchases',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_orders.length} orders',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (_orders.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No purchase orders recorded yet.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
          )
        else
          ..._orders.take(8).map((order) => _buildOrderTile(order)),

        const SizedBox(height: 22),

        // Paper Sales Breakdown
        if (_summary?.papers != null && _summary!.papers.isNotEmpty) ...[
          const Text(
            'Paper Sales Breakdown',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ..._summary!.papers.map((p) => _buildPaperSalesCard(p)),
        ],
      ],
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _metricBox({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTile(ManagerPurchaseOrder order) {
    final isPaid = order.status == 'paid';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
              color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.paperTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  order.studentEmail ?? order.studentName ?? 'Student',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '₹${order.amountRupees}',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperSalesCard(ManagerPaperSalesItem paper) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paper.title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${paper.courseName ?? 'General'} • ₹${paper.priceRupees}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${paper.revenueRupees}',
                style: const TextStyle(
                  color: Color(0xFF16A34A),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${paper.sold} sold',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
