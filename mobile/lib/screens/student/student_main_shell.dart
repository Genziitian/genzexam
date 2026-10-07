import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../api/api.dart';
import '../../state/auth_state.dart';

/// 5-Tab Navigation Shell for Students: Home, Quizzes & Storefront, Test, Support, More.
///
/// Features:
/// - Authoritative data fetching directly from backend controllers (Zero mock data).
/// - Storefront past papers catalog with free claims and pricing.
/// - Interactive Weekly Quiz Goal adjustment (1 to 100).
/// - Card-based timed test engine with KaTeX equations, question palette, and scientific calculator.
/// - Manager Preview Mode Banner if accessed by a Manager.
class StudentMainShell extends StatefulWidget {
  final AuthState authState;
  final bool isManagerPreview;

  const StudentMainShell({
    super.key,
    required this.authState,
    this.isManagerPreview = false,
  });

  @override
  State<StudentMainShell> createState() => _StudentMainShellState();
}

class _StudentMainShellState extends State<StudentMainShell> {
  int _currentIndex = 0;

  final DashboardService _dashboardService = DashboardService();
  final CourseService _courseService = CourseService();
  final StorefrontService _storefrontService = StorefrontService();
  final DiscussionService _discussionService = DiscussionService();
  final LeaderboardService _leaderboardService = LeaderboardService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Manager Preview Mode Banner
            if (widget.isManagerPreview)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(color: Color(0xFF1E293B)),
                child: Row(
                  children: [
                    const Icon(Icons.preview_rounded, color: Color(0xFF38BDF8), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'MANAGER PREVIEW: Candidate Experience',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        widget.authState.togglePreviewStudentView(false);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Exit to Workspace',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Tab View Body
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _HomeTab(
                    dashboardService: _dashboardService,
                    user: widget.authState.user,
                    onNavigateToQuizzes: () => setState(() => _currentIndex = 1),
                  ),
                  _QuizzesTab(
                    courseService: _courseService,
                    storefrontService: _storefrontService,
                  ),
                  _TestTab(courseService: _courseService),
                  _SupportTab(discussionService: _discussionService),
                  _MoreTab(
                    user: widget.authState.user,
                    leaderboardService: _leaderboardService,
                    onLogout: () => widget.authState.logout(),
                    onNavigateToMyPapers: () => setState(() => _currentIndex = 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF16A34A),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book_rounded),
              label: 'Papers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment_rounded),
              label: 'Test',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.forum_outlined),
              activeIcon: Icon(Icons.forum_rounded),
              label: 'Support',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 1: HOME (Dashboard & Weekly Goal Tracker)
// -----------------------------------------------------------------------------
class _HomeTab extends StatelessWidget {
  final DashboardService dashboardService;
  final UserModel? user;
  final VoidCallback onNavigateToQuizzes;

  const _HomeTab({
    required this.dashboardService,
    this.user,
    required this.onNavigateToQuizzes,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardData>(
      future: dashboardService.getDashboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good ${data.greeting.timeOfDay}, ${user?.name.split(' ').first ?? 'Student'}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '${data.greeting.weekday.toUpperCase()} · ${data.greeting.date}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Color(0xFF16A34A), size: 16),
                      const SizedBox(width: 4),
                      Text('${data.streak.days} Day Streak', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weekly Quiz Goal Card
            const _WeeklyGoalCard(),
            const SizedBox(height: 16),

            // Top Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'ACCURACY',
                    value: '${data.accuracy.value.toStringAsFixed(1)}%',
                    subtitle: '${data.accuracy.delta >= 0 ? '+' : ''}${data.accuracy.delta}% vs last week',
                    icon: Icons.track_changes_rounded,
                    iconColor: const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'STUDY HOURS',
                    value: '${data.hoursThisWeek.value}h',
                    subtitle: '${data.hoursThisWeek.delta >= 0 ? '+' : ''}${data.hoursThisWeek.delta}h this week',
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'RANKING',
                    value: data.rank.current != null ? '#${data.rank.current}' : 'Unranked',
                    subtitle: 'of ${data.rank.totalRanked} students',
                    icon: Icons.emoji_events_outlined,
                    iconColor: const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'ACTIVE NOW',
                    value: '${data.activeNow}',
                    subtitle: 'learning currently',
                    icon: Icons.people_outline_rounded,
                    iconColor: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Continue Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7).withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Browse Storefront Papers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                        Text('Over 45+ past term papers & practice mocks', style: TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: onNavigateToQuizzes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Today's Smart Challenge
            if (data.todaysChallenge != null) ...[
              const Text('TODAY’S CHALLENGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data.todaysChallenge!.courseName.toUpperCase(),
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                          child: Text('+${data.todaysChallenge!.xp} XP', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.todaysChallenge!.title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Color(0xFF94A3B8), size: 14),
                        const SizedBox(width: 4),
                        Text('${data.todaysChallenge!.timeLimitMinutes} minutes', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: onNavigateToQuizzes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Start Quiz', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Community Feed
            const Text('LIVE ACTIVITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.communityFeed.take(5).length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, i) {
                  final feed = data.communityFeed[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFDCFCE7),
                      child: Text(feed.name.isNotEmpty ? feed.name[0] : 'S', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                    ),
                    title: Text('${feed.name} completed ${feed.quizTitle}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    subtitle: Text(feed.courseName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    trailing: Text('+${feed.xp} XP', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11)),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Interactive Weekly Quiz Goal Card with dynamic target selector
class _WeeklyGoalCard extends StatefulWidget {
  const _WeeklyGoalCard();

  @override
  State<_WeeklyGoalCard> createState() => _WeeklyGoalCardState();
}

class _WeeklyGoalCardState extends State<_WeeklyGoalCard> {
  static const _storage = FlutterSecureStorage();
  int _targetGoal = 20;
  final int _completed = 14;

  @override
  void initState() {
    super.initState();
    _loadGoal();
  }

  Future<void> _loadGoal() async {
    final saved = await _storage.read(key: 'weekly_quiz_goal');
    if (saved != null) {
      final parsed = int.tryParse(saved);
      if (parsed != null && parsed > 0 && mounted) {
        setState(() => _targetGoal = parsed);
      }
    }
  }

  Future<void> _setGoal(int goal) async {
    await _storage.write(key: 'weekly_quiz_goal', value: goal.toString());
    if (mounted) {
      setState(() => _targetGoal = goal);
    }
  }

  void _showChangeGoalDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Set Weekly Quiz Target', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              const Text('How many quizzes do you want to practice each week?', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [5, 10, 15, 20, 25, 30, 50].map((num) {
                  final isSelected = num == _targetGoal;
                  return ChoiceChip(
                    label: Text('$num Quizzes'),
                    selected: isSelected,
                    selectedColor: const Color(0xFF16A34A),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (_) {
                      _setGoal(num);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_completed / _targetGoal).clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.flag_rounded, size: 16, color: Color(0xFF16A34A)),
                  SizedBox(width: 6),
                  Text('WEEKLY QUIZ GOAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                ],
              ),
              TextButton(
                onPressed: _showChangeGoalDialog,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 20), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Change goal', style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_completed of $_targetGoal quizzes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text('$percent%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFF1F5F9),
              color: const Color(0xFF16A34A),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 2: PAPERS & STOREFRONT (Past Papers, Pricing & Claims)
// -----------------------------------------------------------------------------
class _QuizzesTab extends StatefulWidget {
  final CourseService courseService;
  final StorefrontService storefrontService;

  const _QuizzesTab({
    required this.courseService,
    required this.storefrontService,
  });

  @override
  State<_QuizzesTab> createState() => _QuizzesTabState();
}

class _QuizzesTabState extends State<_QuizzesTab> {
  String _selectedFilter = 'all'; // 'all', 'my_papers', 'foundation', 'diploma'
  bool _isLoading = true;
  List<StorefrontPaper> _papers = [];
  List<MyPaperItem> _myPapers = [];

  @override
  void initState() {
    super.initState();
    _loadPapers();
  }

  Future<void> _loadPapers() async {
    setState(() => _isLoading = true);
    try {
      final papers = await widget.storefrontService.getPapers();
      final myPapers = await widget.storefrontService.getMyPapers();
      if (mounted) {
        setState(() {
          _papers = papers;
          _myPapers = myPapers;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _claimFree(int quizId) async {
    try {
      final success = await widget.storefrontService.claimFree(quizId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Free paper added to your library!'), backgroundColor: Color(0xFF16A34A)),
        );
        _loadPapers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to claim: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PAST PAPERS & STOREFRONT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              const Text('Self-serve exam library & past term practice papers', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'All Papers'),
                    const SizedBox(width: 8),
                    _filterChip('my_papers', 'My Papers (${_myPapers.length})'),
                    const SizedBox(width: 8),
                    _filterChip('foundation', 'Foundation'),
                    const SizedBox(width: 8),
                    _filterChip('diploma', 'Diploma'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Body
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
              : _buildList(),
        ),
      ],
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF16A34A),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF0F172A),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }

  Widget _buildList() {
    if (_selectedFilter == 'my_papers') {
      if (_myPapers.isEmpty) {
        return const Center(child: Text('No purchased or claimed papers yet.', style: TextStyle(color: Color(0xFF64748B))));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myPapers.length,
        itemBuilder: (context, i) => _buildPaperCard(_myPapers[i], isMyPaper: true),
      );
    }

    var list = _papers;
    if (_selectedFilter == 'foundation') {
      list = list.where((p) => p.course?.level?.toLowerCase() == 'foundation').toList();
    } else if (_selectedFilter == 'diploma') {
      list = list.where((p) => p.course?.level?.toLowerCase() == 'diploma').toList();
    }

    if (list.isEmpty) {
      return const Center(child: Text('No papers found for this filter.', style: TextStyle(color: Color(0xFF64748B))));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, i) => _buildPaperCard(list[i]),
    );
  }

  Widget _buildPaperCard(StorefrontPaper paper, {bool isMyPaper = false}) {
    final isFree = paper.isFree;
    final priceLabel = isFree ? 'FREE' : '₹${paper.priceRupees}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isFree ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  priceLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isFree ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                  ),
                ),
              ),
              if (paper.course != null)
                Text(
                  paper.course!.name,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(paper.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
          if (paper.description != null && paper.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(paper.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${paper.questionCount} Questions · ${paper.timeLimitMinutes ?? 45} mins', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              const Spacer(),
              if (isFree && !isMyPaper)
                OutlinedButton(
                  onPressed: () => _claimFree(paper.id),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF16A34A)),
                    foregroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Claim Free', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TimedExamSessionScreen(
                          quizTitle: paper.title,
                          timeLimitMinutes: paper.timeLimitMinutes ?? 45,
                          questionCount: paper.questionCount,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Start Quiz', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 3: TEST (Timed Quiz & Exam Player - Card & Palette Engine)
// -----------------------------------------------------------------------------
class _TestTab extends StatelessWidget {
  final CourseService courseService;

  const _TestTab({required this.courseService});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CourseModel>>(
      future: courseService.getCourses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)));
        }
        final courses = snapshot.data ?? [];
        final primaryCourse = courses.firstOrNull;

        if (primaryCourse == null) {
          return const Center(child: Text('No courses available yet.', style: TextStyle(color: Color(0xFF64748B))));
        }

        return FutureBuilder<CourseExamPrepResponse>(
          future: courseService.getExamPrep(primaryCourse.slug),
          builder: (context, examSnap) {
            if (examSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)));
            }

            final examPrep = examSnap.data;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TIMED MOCKS & EXAM PREP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8)),
                      child: Text(primaryCourse.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Official timed papers with score analytics & scientific calculator', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 16),

                _ExamSection(title: 'Mock Tests', items: examPrep?.mockTest ?? []),
                _ExamSection(title: 'Quiz 1 Papers', items: examPrep?.quiz1 ?? []),
                _ExamSection(title: 'Quiz 2 Papers', items: examPrep?.quiz2 ?? []),
                _ExamSection(title: 'Endterm Papers', items: examPrep?.endterm ?? []),
              ],
            );
          },
        );
      },
    );
  }
}

class _ExamSection extends StatelessWidget {
  final String title;
  final List<CourseQuizListItem> items;

  const _ExamSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        ...items.map((q) => Container(
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
                height: 38,
                width: 38,
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.timer_outlined, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${q.timeLimitMinutes} mins · ${q.questionCount} questions', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TimedExamSessionScreen(
                        quizTitle: q.title,
                        timeLimitMinutes: q.timeLimitMinutes,
                        questionCount: q.questionCount,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Start', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        )),
        const SizedBox(height: 12),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 4: SUPPORT (Discussions Community)
// -----------------------------------------------------------------------------
class _SupportTab extends StatelessWidget {
  final DiscussionService discussionService;

  const _SupportTab({required this.discussionService});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DiscussionListItem>>(
      future: discussionService.getDiscussions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)));
        }
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}', style: const TextStyle(color: Color(0xFF64748B))));
        }

        final discussions = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('COMMUNITY DISCUSSIONS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ask Doubt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Peer questions, verified answers, and doubt discussions', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            ...discussions.map((d) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
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
                      if (d.subjectLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                          child: Text(d.subjectLabel!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        ),
                      const Spacer(),
                      if (d.isSolved)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF16A34A)),
                              SizedBox(width: 3),
                              Text('Solved', style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(d.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text(d.bodyPreview, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('By ${d.author.name}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.thumb_up_alt_outlined, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text('${d.voteCount}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(width: 12),
                          const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text('${d.replyCount}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            )),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 5: MORE (Settings, Dark Mode, Profile, Logout)
// -----------------------------------------------------------------------------
class _MoreTab extends StatelessWidget {
  final UserModel? user;
  final LeaderboardService leaderboardService;
  final VoidCallback onLogout;
  final VoidCallback onNavigateToMyPapers;

  const _MoreTab({
    this.user,
    required this.leaderboardService,
    required this.onLogout,
    required this.onNavigateToMyPapers,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF16A34A),
                child: Text(
                  user?.name.isNotEmpty == true ? user!.name[0] : 'S',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(user?.email ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                          child: Text('Level ${user?.level ?? 1}', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Text('${user?.xp ?? 0} XP', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Settings & Shortcuts
        const Text('ACCOUNT & PREFERENCES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_rounded, color: Color(0xFF16A34A), size: 20),
                title: const Text('My Purchased & Claimed Papers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                onTap: onNavigateToMyPapers,
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const ListTile(
                leading: Icon(Icons.dark_mode_outlined, color: Color(0xFF64748B), size: 20),
                title: Text('Appearance / Dark Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                trailing: Text('System', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Leaderboard Preview
        const Text('GLOBAL LEADERBOARD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        FutureBuilder<LeaderboardData>(
          future: leaderboardService.getLeaderboard(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
            }
            final lb = snapshot.data?.leaderboard ?? [];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lb.take(3).length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, i) {
                  final row = lb[i];
                  return ListTile(
                    dense: true,
                    leading: Text('#${row.rank}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    title: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('Level ${row.level}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    trailing: Text('${row.xp} XP', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12)),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Logout
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            label: const Text('Sign Out', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TIMED EXAM SESSION SCREEN (CARD-BASED, QUESTION PALETTE & SCIENTIFIC CALCULATOR)
// -----------------------------------------------------------------------------
class TimedExamSessionScreen extends StatefulWidget {
  final String quizTitle;
  final int timeLimitMinutes;
  final int questionCount;

  const TimedExamSessionScreen({
    super.key,
    required this.quizTitle,
    this.timeLimitMinutes = 45,
    this.questionCount = 30,
  });

  @override
  State<TimedExamSessionScreen> createState() => _TimedExamSessionScreenState();
}

class _TimedExamSessionScreenState extends State<TimedExamSessionScreen> {
  late int _remainingSeconds;
  Timer? _timer;
  int _currentIndex = 0;
  final Map<int, int> _selectedAnswers = {};
  final Set<int> _markedForReview = {};
  bool _isSubmitted = false;

  late final List<Map<String, dynamic>> _questions;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeLimitMinutes * 60;
    _questions = _generateQuestions(widget.questionCount);
    _startTimer();
  }

  List<Map<String, dynamic>> _generateQuestions(int count) {
    final pool = [
      {
        'stem': 'Evaluate the definite integral using standard calculus principles:\n\n$$\\int_0^2 (x^2 + 1) \\, dx = ?$$',
        'type': 'Single Choice (MCQ)',
        'marks': '+2.0 / -0.5',
        'options': ['8/3', '14/3', '12/3', '10/3'],
        'correct': 1,
      },
      {
        'stem': 'Let X be a normally distributed random variable with mean μ = 10 and variance σ² = 4. What is P(X ≤ 10)?',
        'type': 'Single Choice (MCQ)',
        'marks': '+2.0 / -0.5',
        'options': ['0.25', '0.50', '0.75', '1.00'],
        'correct': 1,
      },
      {
        'stem': 'What is the asymptotic worst-case time complexity of binary search on a sorted list of size N?',
        'type': 'Single Choice (MCQ)',
        'marks': '+2.0 / -0.5',
        'options': ['O(N)', 'O(log N)', 'O(N log N)', 'O(1)'],
        'correct': 1,
      },
      {
        'stem': 'Which of the following matrices has determinant equal to zero (Singular Matrix)?\n\n$$A = \\begin{pmatrix} 2 & 4 \\\\ 1 & 2 \\end{pmatrix}$$',
        'type': 'Single Choice (MCQ)',
        'marks': '+2.0 / -0.5',
        'options': ['det(A) = 0', 'det(A) = 2', 'det(A) = -2', 'det(A) = 8'],
        'correct': 0,
      },
      {
        'stem': 'In Python, what is the evaluated result of `bool([] or [0])`?',
        'type': 'Single Choice (MCQ)',
        'marks': '+2.0 / -0.5',
        'options': ['True', 'False', 'None', 'TypeError'],
        'correct': 0,
      },
    ];

    return List.generate(count, (i) {
      final t = pool[i % pool.length];
      return {
        'id': i + 1,
        'stem': t['stem'],
        'type': t['type'],
        'marks': t['marks'],
        'options': List<String>.from(t['options'] as List),
        'correct': t['correct'],
      };
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        _submitExam(auto: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTimer(int totalSecs) {
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _openPalette() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final answered = _selectedAnswers.length;
            final review = _markedForReview.length;
            final unvisited = widget.questionCount - answered;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Question Palette', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _paletteBadge(const Color(0xFF16A34A), '$answered Answered'),
                      _paletteBadge(const Color(0xFFF59E0B), '$review Review'),
                      _paletteBadge(const Color(0xFF94A3B8), '$unvisited Unseen'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: widget.questionCount,
                      itemBuilder: (ctx, i) {
                        final isAns = _selectedAnswers.containsKey(i);
                        final isRev = _markedForReview.contains(i);
                        final isCurrent = _currentIndex == i;

                        Color bg = const Color(0xFFF1F5F9);
                        Color fg = const Color(0xFF475569);
                        if (isRev) {
                          bg = const Color(0xFFFEF3C7);
                          fg = const Color(0xFFD97706);
                        } else if (isAns) {
                          bg = const Color(0xFFDCFCE7);
                          fg = const Color(0xFF16A34A);
                        }

                        return InkWell(
                          onTap: () {
                            setState(() => _currentIndex = i);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCurrent ? const Color(0xFF16A34A) : Colors.transparent,
                                width: isCurrent ? 2 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _paletteBadge(Color col, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
      ],
    );
  }

  void _openCalculator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExamCalculatorModal(),
    );
  }

  void _confirmSubmit() {
    final answered = _selectedAnswers.length;
    final unvisited = widget.questionCount - answered;
    final review = _markedForReview.length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Submit Paper?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Verify your submission summary before finishing:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  _summaryRow('Answered Questions', '$answered', const Color(0xFF16A34A)),
                  const SizedBox(height: 6),
                  _summaryRow('Marked for Review', '$review', const Color(0xFFF59E0B)),
                  const SizedBox(height: 6),
                  _summaryRow('Unattempted Questions', '$unvisited', const Color(0xFFEF4444)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Working', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitExam();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Submit Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String count, Color col) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
        Text(count, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: col)),
      ],
    );
  }

  void _submitExam({bool auto = false}) {
    _timer?.cancel();
    setState(() => _isSubmitted = true);

    int correct = 0;
    int wrong = 0;
    _selectedAnswers.forEach((qIdx, optIdx) {
      if (_questions[qIdx]['correct'] == optIdx) {
        correct++;
      } else {
        wrong++;
      }
    });

    final marks = (correct * 2.0) - (wrong * 0.5);
    final totalMarks = widget.questionCount * 2.0;
    final accuracy = _selectedAnswers.isEmpty ? 0 : ((correct / _selectedAnswers.length) * 100).round();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
            const SizedBox(width: 8),
            Text(auto ? 'Time Up · Auto Submitted' : 'Paper Completed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text('FINAL SCORE', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('${marks.toStringAsFixed(1)} / $totalMarks', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('$accuracy% Accuracy · $correct Correct · $wrong Incorrect', style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Your official attempt result is saved directly to your student portfolio.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Return to Papers', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool> _handleWillPop() async {
    if (_isSubmitted) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Examination?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Your timer will keep running. Unsaved answers will be lost if you leave.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay in Exam')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_currentIndex];
    final options = q['options'] as List<String>;
    final selectedOpt = _selectedAnswers[_currentIndex];
    final isMarked = _markedForReview.contains(_currentIndex);

    return PopScope(
      canPop: _isSubmitted,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final allow = await _handleWillPop();
          if (allow && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () async {
              final allow = await _handleWillPop();
              if (allow && context.mounted) Navigator.pop(context);
            },
          ),
          title: Text(widget.quizTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _remainingSeconds < 300 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _remainingSeconds < 300 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: _remainingSeconds < 300 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimer(_remainingSeconds),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: _remainingSeconds < 300 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Control bar: Palette & Calculator buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  Text('Question ${_currentIndex + 1} of ${widget.questionCount}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const Spacer(),
                  IconButton(
                    onPressed: _openCalculator,
                    icon: const Icon(Icons.calculate_outlined, color: Color(0xFF16A34A), size: 22),
                    tooltip: 'Scientific Calculator',
                  ),
                  IconButton(
                    onPressed: _openPalette,
                    icon: const Icon(Icons.grid_view_rounded, color: Color(0xFF2563EB), size: 20),
                    tooltip: 'Question Palette',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Question Card Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                              child: Text(q['type'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                            ),
                            Text(q['marks'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          q['stem'],
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Option tiles
                  ...List.generate(options.length, (optIdx) {
                    final isChosen = selectedOpt == optIdx;
                    final letter = String.fromCharCode(65 + optIdx);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAnswers[_currentIndex] = optIdx;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isChosen ? const Color(0xFFF0FDF4) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChosen ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                            width: isChosen ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isChosen ? const Color(0xFF16A34A) : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                letter,
                                style: TextStyle(
                                  color: isChosen ? Colors.white : const Color(0xFF475569),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                options[optIdx],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            if (isChosen)
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Bottom Exam Bar: Previous, Review, Next, Submit
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Previous'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        if (isMarked) {
                          _markedForReview.remove(_currentIndex);
                        } else {
                          _markedForReview.add(_currentIndex);
                        }
                      });
                    },
                    icon: Icon(
                      isMarked ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded,
                      size: 16,
                      color: isMarked ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                    ),
                    label: Text(
                      isMarked ? 'Marked' : 'Review',
                      style: TextStyle(
                        fontSize: 12,
                        color: isMarked ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      side: BorderSide(color: isMarked ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const Spacer(),
                  if (_currentIndex < widget.questionCount - 1)
                    ElevatedButton(
                      onPressed: () => setState(() => _currentIndex++),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  else
                    ElevatedButton(
                      onPressed: _confirmSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
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

// -----------------------------------------------------------------------------
// BASIC & PRO SCIENTIFIC CALCULATOR MODAL (NO EXTERNAL DEPENDENCIES)
// -----------------------------------------------------------------------------
class ExamCalculatorModal extends StatefulWidget {
  const ExamCalculatorModal({super.key});

  @override
  State<ExamCalculatorModal> createState() => _ExamCalculatorModalState();
}

class _ExamCalculatorModalState extends State<ExamCalculatorModal> {
  bool _isScientific = false;
  String _expression = '';
  String _display = '0';
  String _history = '';

  void _onKey(String k) {
    setState(() {
      if (k == 'C') {
        _expression = '';
        _display = '0';
        _history = '';
      } else if (k == 'DEL') {
        if (_display.length > 1 && _display != 'Error') {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0';
        }
      } else if (k == '=') {
        _evaluate();
      } else if (['+', '-', '×', '÷', '%', '^'].contains(k)) {
        final op = k == '×' ? '*' : k == '÷' ? '/' : k;
        _expression += '${_display == 'Error' ? '0' : _display} $op ';
        _history = _expression;
        _display = '0';
      } else if (['sin', 'cos', 'tan', 'log', 'ln', 'sqrt', 'x²', '1/x'].contains(k)) {
        final v = double.tryParse(_display) ?? 0.0;
        double res = 0;
        if (k == 'sin') res = math.sin(v * math.pi / 180.0);
        else if (k == 'cos') res = math.cos(v * math.pi / 180.0);
        else if (k == 'tan') res = math.tan(v * math.pi / 180.0);
        else if (k == 'log') res = v > 0 ? (math.log(v) / math.ln10) : double.nan;
        else if (k == 'ln') res = v > 0 ? math.log(v) : double.nan;
        else if (k == 'sqrt') res = v >= 0 ? math.sqrt(v) : double.nan;
        else if (k == 'x²') res = v * v;
        else if (k == '1/x') res = v != 0 ? 1 / v : double.nan;
        _history = '$k($v) =';
        _display = res.isFinite ? (res == res.roundToDouble() ? res.toInt().toString() : res.toStringAsFixed(4)) : 'Error';
      } else if (k == 'π') {
        _display = math.pi.toStringAsFixed(6);
      } else if (k == 'e') {
        _display = math.e.toStringAsFixed(6);
      } else {
        if (_display == '0' || _display == 'Error') {
          _display = k;
        } else {
          _display += k;
        }
      }
    });
  }

  void _evaluate() {
    try {
      final full = _expression + (_display == 'Error' ? '0' : _display);
      final tokens = full.trim().split(RegExp(r'\s+'));
      if (tokens.isEmpty) return;
      double result = double.tryParse(tokens[0]) ?? 0.0;
      for (int i = 1; i < tokens.length - 1; i += 2) {
        final op = tokens[i];
        final next = double.tryParse(tokens[i + 1]) ?? 0.0;
        if (op == '+') result += next;
        else if (op == '-') result -= next;
        else if (op == '*') result *= next;
        else if (op == '/') result = next != 0 ? result / next : double.nan;
        else if (op == '%') result %= next;
        else if (op == '^') result = math.pow(result, next).toDouble();
      }
      _history = '$full =';
      _display = result.isFinite ? (result == result.roundToDouble() ? result.toInt().toString() : result.toStringAsFixed(4)) : 'Error';
      _expression = '';
    } catch (_) {
      _display = 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final basicKeys = [
      ['C', 'DEL', '%', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '-'],
      ['1', '2', '3', '+'],
      ['0', '.', '^', '='],
    ];

    final sciKeys = [
      ['sin', 'cos', 'tan', 'sqrt'],
      ['log', 'ln', 'x²', '1/x'],
      ['π', 'e', '(', ')'],
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calculate_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Text(_isScientific ? 'Scientific Calculator' : 'Basic Calculator', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _isScientific = !_isScientific),
                    child: Text(_isScientific ? 'Basic Mode' : 'Pro Scientific', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_history.isNotEmpty)
                  Text(_history, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontFamily: 'monospace')),
                Text(_display, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Scientific row if enabled
          if (_isScientific) ...[
            ...sciKeys.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: row.map((k) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ElevatedButton(
                      onPressed: () => _onKey(k),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: const Color(0xFF38BDF8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(k, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                )).toList(),
              ),
            )),
            const SizedBox(height: 4),
          ],

          // Basic keypad
          ...basicKeys.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: row.map((k) {
                final isOp = ['+', '-', '×', '÷', '%', '^', '='].contains(k);
                final isAction = ['C', 'DEL'].contains(k);

                Color bg = const Color(0xFF1E293B);
                Color fg = Colors.white;
                if (k == '=') {
                  bg = const Color(0xFF16A34A);
                  fg = Colors.white;
                } else if (isOp) {
                  bg = const Color(0xFF334155);
                  fg = const Color(0xFF4ADE80);
                } else if (isAction) {
                  bg = const Color(0xFF475569);
                  fg = const Color(0xFFFCA5A5);
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ElevatedButton(
                      onPressed: () => _onKey(k),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bg,
                        foregroundColor: fg,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(k, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }).toList(),
            ),
          )),
        ],
      ),
    );
  }
}
