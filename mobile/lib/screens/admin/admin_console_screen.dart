import 'package:flutter/material.dart';
import '../../api/api.dart';
import '../../state/auth_state.dart';
import '../../widgets/app_ux_components.dart';

/// Real Admin Console for Admin (rank 1) and Manager (rank 2) roles.
/// Communicates with backend/app/Http/Controllers/Admin/AdminUserController.php
/// and AdminDashboardController.php.
class AdminConsoleScreen extends StatefulWidget {
  final AuthState authState;

  const AdminConsoleScreen({super.key, required this.authState});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  final AdminService _adminService = AdminService();

  String _search = '';
  String _filter = 'all';
  int _page = 1;
  bool _isLoadingAction = false;

  void _refresh() {
    setState(() {});
  }

  Future<void> _toggleActive(AdminUserListItem user) async {
    setState(() => _isLoadingAction = true);
    try {
      await _adminService.toggleActive(user.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated active status for ${user.name}')),
      );
      _refresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _togglePro(AdminUserListItem user) async {
    setState(() => _isLoadingAction = true);
    try {
      await _adminService.togglePro(user.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated Pro status for ${user.name}')),
      );
      _refresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authState.user;
    final isManager = widget.authState.isManager;

    return AppKeyboardDismiss(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin Console',
                style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '${user?.name ?? 'Admin'} · ${user?.role?.toUpperCase() ?? 'ADMIN'}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            if (isManager)
              IconButton(
                icon: const Icon(Icons.visibility_rounded, color: Color(0xFF2563EB)),
                tooltip: 'Preview student app',
                onPressed: () {
                  AppHaptics.light();
                  widget.authState.togglePreviewStudentView(true);
                },
              ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
              onPressed: () {
                AppHaptics.medium();
                widget.authState.logout();
              },
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              AppHaptics.light();
              _refresh();
            },
            color: const Color(0xFF16A34A),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
            // KPI Stats Overview
            FutureBuilder<AdminStatsResponse>(
              future: _adminService.getStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator(color: Color(0xFF16A34A));
                }
                if (snapshot.hasError) {
                  return Text('Error loading stats: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                }

                final stats = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PLATFORM KPIS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _KpiMiniCard(label: 'Students', value: '${stats.totalStudents}', icon: Icons.people_outline)),
                        const SizedBox(width: 8),
                        Expanded(child: _KpiMiniCard(label: 'Quizzes', value: '${stats.totalQuizzes}', icon: Icons.quiz_outlined)),
                        const SizedBox(width: 8),
                        Expanded(child: _KpiMiniCard(label: 'Attempts Today', value: '${stats.totalAttemptsToday}', icon: Icons.timer_outlined)),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),

            // User Management Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('USER MANAGEMENT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text('Filter: ${_filter.toUpperCase()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 8),

            // Search Bar
            TextField(
              onChanged: (val) {
                setState(() {
                  _search = val;
                  _page = 1;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search user name or email...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 10),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'All', value: 'all', selected: _filter == 'all', onSelect: (v) => setState(() => _filter = v)),
                  _FilterChip(label: 'Students', value: 'students', selected: _filter == 'students', onSelect: (v) => setState(() => _filter = v)),
                  _FilterChip(label: 'Pro', value: 'pro', selected: _filter == 'pro', onSelect: (v) => setState(() => _filter = v)),
                  _FilterChip(label: 'Inactive', value: 'inactive', selected: _filter == 'inactive', onSelect: (v) => setState(() => _filter = v)),
                  _FilterChip(label: 'Admins', value: 'admins', selected: _filter == 'admins', onSelect: (v) => setState(() => _filter = v)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // User List
            FutureBuilder<AdminUserListResponse>(
              future: _adminService.getUsers(search: _search, filter: _filter, page: _page),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return AppShimmerCard.list(count: 3);
                }
                if (snapshot.hasError) {
                  return AppErrorCard(
                    title: 'Unable to Load Users',
                    message: '${snapshot.error}',
                    onRetry: _refresh,
                  );
                }

                final users = snapshot.data?.data ?? [];
                if (users.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: const Text('No users match this filter.', style: TextStyle(color: Color(0xFF94A3B8))),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final u = users[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFE2E8F0),
                                child: Text(
                                  u.name.isNotEmpty ? u.name[0] : 'U',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(u.email, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: u.role == 'manager'
                                      ? const Color(0xFFEDE9FE)
                                      : u.role == 'admin'
                                          ? const Color(0xFFDBEAFE)
                                          : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  u.role.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: u.role == 'manager'
                                        ? const Color(0xFF7C3AED)
                                        : u.role == 'admin'
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('${u.xp} XP', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: u.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  u.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: u.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                              if (u.isPro) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                                ),
                              ],
                              const Spacer(),
                              if (u.can.toggleActive)
                                TextButton(
                                  onPressed: _isLoadingAction ? null : () => _toggleActive(u),
                                  child: Text(u.isActive ? 'Deactivate' : 'Activate', style: TextStyle(fontSize: 11, color: u.isActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A))),
                                ),
                              if (u.can.togglePro)
                                TextButton(
                                  onPressed: _isLoadingAction ? null : () => _togglePro(u),
                                  child: Text(u.isPro ? 'Revoke Pro' : 'Grant Pro', style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB))),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _KpiMiniCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onSelect;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          AppHaptics.selection();
          onSelect(value);
        },
        selectedColor: const Color(0xFFDCFCE7),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: selected ? const Color(0xFF16A34A) : const Color(0xFF475569),
        ),
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
