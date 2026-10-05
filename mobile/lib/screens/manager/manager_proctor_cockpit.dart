import 'dart:async';
import 'package:flutter/material.dart';
import '../../api/api.dart';
import '../../state/auth_state.dart';
import '../admin/admin_console_screen.dart';

/// Real Manager Proctor Cockpit (Proctored B2B SaaS Engine Control).
///
/// Communicates directly with backend/app/Http/Controllers/ExamPlatformController.php:
/// - Real-time state polling (/api/exam-platform/state)
/// - Proctored actions (/api/exam-platform/action)
/// - Authoritative exam reset (/api/exam-platform/reset)
/// - Instant toggle to 'Preview Student View'
class ManagerProctorCockpit extends StatefulWidget {
  final AuthState authState;

  const ManagerProctorCockpit({super.key, required this.authState});

  @override
  State<ManagerProctorCockpit> createState() => _ManagerProctorCockpitState();
}

class _ManagerProctorCockpitState extends State<ManagerProctorCockpit> {
  final ExamPlatformService _examService = ExamPlatformService();
  Timer? _pollingTimer;

  Map<String, dynamic>? _examState;
  bool _isLoading = true;
  bool _isActionRunning = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchState();
    // 5-second polling for live exam monitor
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchState(isBackground: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchState({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() => _isLoading = true);
    }
    try {
      final state = await _examService.getState();
      if (mounted) {
        setState(() {
          _examState = state;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted && !isBackground) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _dispatchAction(String action, [Map<String, dynamic>? extra]) async {
    setState(() => _isActionRunning = true);
    try {
      await _examService.dispatchAction(action, extra);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action "$action" executed successfully')),
      );
      await _fetchState();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionRunning = false);
      }
    }
  }

  Future<void> _handleReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Exam State?'),
        content: const Text(
          'This will purge all active student exam sessions, answers, chat, and re-entry queues back to the factory defaults.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Reset Exam', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionRunning = true);
    try {
      await _examService.resetState();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exam state has been authoritatively reset.')),
      );
      await _fetchState();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionRunning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final exam = (_examState?['exam'] as Map<String, dynamic>?) ?? {};
    final status = (exam['status'] ?? 'paused') as String;
    final title = (exam['title'] ?? 'Exam Platform') as String;
    final sessions = (_examState?['studentSessions'] as Map<String, dynamic>?) ?? {};
    final reentry = (_examState?['reentryRequests'] as List?) ?? [];

    Color statusColor;
    switch (status) {
      case 'live':
        statusColor = const Color(0xFF16A34A);
        break;
      case 'paused':
        statusColor = const Color(0xFFD97706);
        break;
      case 'ended':
      default:
        statusColor = const Color(0xFF64748B);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'MANAGER',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Proctor Cockpit',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Preview Student View Button
          ElevatedButton.icon(
            onPressed: () {
              widget.authState.togglePreviewStudentView(true);
            },
            icon: const Icon(Icons.remove_red_eye_rounded, size: 14),
            label: const Text('Student View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),

          // User Admin Console Button
          IconButton(
            icon: const Icon(Icons.manage_accounts_rounded, color: Colors.white70),
            tooltip: 'User Management Console',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminConsoleScreen(authState: widget.authState)),
              );
            },
          ),

          // Logout
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFF87171)),
            onPressed: () => widget.authState.logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
            : RefreshIndicator(
                onRefresh: () => _fetchState(),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Live Exam Banner Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      height: 8,
                                      width: 8,
                                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      status.toUpperCase(),
                                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${sessions.length} Candidates',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            exam['subject'] ?? 'Proctored Assessment',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                          const SizedBox(height: 16),

                          // Quick Control Buttons
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (status != 'live')
                                ElevatedButton.icon(
                                  onPressed: _isActionRunning ? null : () => _dispatchAction('start_exam'),
                                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                  label: const Text('Start / Resume Exam'),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                                ),
                              if (status == 'live')
                                ElevatedButton.icon(
                                  onPressed: _isActionRunning ? null : () => _dispatchAction('pause_exam'),
                                  icon: const Icon(Icons.pause_rounded, size: 16),
                                  label: const Text('Pause Exam'),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                                ),
                              ElevatedButton.icon(
                                onPressed: _isActionRunning ? null : () => _dispatchAction('extend_time', {'minutes': 5}),
                                icon: const Icon(Icons.more_time_rounded, size: 16),
                                label: const Text('+5 Mins Time'),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                              ),
                              if (status != 'ended')
                                ElevatedButton.icon(
                                  onPressed: _isActionRunning ? null : () => _dispatchAction('end_exam'),
                                  icon: const Icon(Icons.stop_rounded, size: 16),
                                  label: const Text('End Exam'),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                                ),
                              OutlinedButton.icon(
                                onPressed: _isActionRunning ? null : _handleReset,
                                icon: const Icon(Icons.restore_rounded, size: 16, color: Color(0xFFF87171)),
                                label: const Text('Factory Reset', style: TextStyle(color: Color(0xFFF87171))),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFEF4444))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Reentry Requests Section
                    const Text('RE-ENTRY REQUESTS QUEUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 8),
                    if (reentry.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Text('No students requesting re-entry lock clearance.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      )
                    else
                      ...reentry.map((r) {
                        final req = r as Map<String, dynamic>;
                        final reqId = req['id'] ?? '';
                        final email = req['email'] ?? '';
                        final name = req['name'] ?? 'Candidate';
                        final reason = req['reason'] ?? 'Tab switch / Disconnect';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(email, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text('Reason: $reason', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11)),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _dispatchAction('approve_reentry', {'requestId': reqId, 'email': email}),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                                child: const Text('Approve', style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                onPressed: () => _dispatchAction('reject_reentry', {'requestId': reqId}),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFEF4444))),
                                child: const Text('Reject', style: TextStyle(color: Color(0xFFF87171), fontSize: 11)),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 20),

                    // Active Candidate Sessions
                    const Text('CANDIDATE LIVE SESSIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 8),
                    if (sessions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Text('No active candidates in this exam session.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      )
                    else
                      ...sessions.entries.map((entry) {
                        final email = entry.key;
                        final s = (entry.value as Map<String, dynamic>?) ?? {};
                        final sessStatus = s['status'] ?? 'in_progress';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(email, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text('Status: ${sessStatus.toString().toUpperCase()}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                  ],
                                ),
                              ),
                              if (sessStatus == 'in_progress')
                                OutlinedButton(
                                  onPressed: () => _dispatchAction('lock_session', {'email': email}),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFF59E0B))),
                                  child: const Text('Lock Session', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11)),
                                ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}
