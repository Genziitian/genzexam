import 'package:flutter/material.dart';
import '../../api/api.dart';
import '../../state/auth_state.dart';

/// 5-Tab Navigation Shell for Students: Home, Quizzes, Test, Support, More.
///
/// Features:
/// - Authoritative data fetching directly from backend controllers.
/// - Zero local caching drama.
/// - Manager Preview Mode Banner if accessed by a Manager in preview mode.
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
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.preview_rounded, color: Color(0xFF38BDF8), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'MANAGER PREVIEW: Candidate Experience',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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
                          'Exit to Cockpit',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
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
                  _HomeTab(dashboardService: _dashboardService, user: widget.authState.user),
                  _QuizzesTab(courseService: _courseService),
                  _TestTab(courseService: _courseService),
                  _SupportTab(discussionService: _discussionService),
                  _MoreTab(
                    user: widget.authState.user,
                    leaderboardService: _leaderboardService,
                    onLogout: () => widget.authState.logout(),
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
              icon: Icon(Icons.auto_stories_outlined),
              activeIcon: Icon(Icons.auto_stories_rounded),
              label: 'Quizzes',
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
// TAB 1: HOME (Dashboard)
// -----------------------------------------------------------------------------
class _HomeTab extends StatelessWidget {
  final DashboardService dashboardService;
  final UserModel? user;

  const _HomeTab({required this.dashboardService, this.user});

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
              mainAxisAlignment: MainAxisAlignment.between,
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
                      mainAxisAlignment: MainAxisAlignment.between,
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
                          onPressed: () {},
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
            mainAxisAlignment: MainAxisAlignment.between,
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
// TAB 2: QUIZZES (Courses & Weekly Quizzes)
// -----------------------------------------------------------------------------
class _QuizzesTab extends StatelessWidget {
  final CourseService courseService;

  const _QuizzesTab({required this.courseService});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CourseModel>>(
      future: courseService.getCourses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)));
        }
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}', style: const TextStyle(color: Color(0xFF64748B))));
        }

        final courses = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('COURSES & QUIZZES', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Select a course to view weekly practice sets and graded quizzes', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            ...courses.map((c) => Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.code_rounded, color: Color(0xFF0F172A)),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(c.description ?? 'Full academic course material', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (c.level != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(6)),
                            child: Text(c.level!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          ),
                        if (c.hasIde) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                            child: const Text('IDE Problems', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                onTap: () {
                  // Direct navigation to weekly quizzes
                },
              ),
            )),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 3: TEST (Exam Prep - Quiz 1, Quiz 2, Endterm, Mock Tests)
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
                  mainAxisAlignment: MainAxisAlignment.between,
                  children: [
                    const Text('EXAM PREP & MOCKS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8)),
                      child: Text(primaryCourse.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Official timed mocks, Quiz 1, Quiz 2, and Endterm papers', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
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
                    Text('${q.timeLimitMinutes} mins · ${q.questionCount} questions ${q.year != null ? '· Year ${q.year}' : ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              mainAxisAlignment: MainAxisAlignment.between,
              children: [
                const Text('STUDY SUPPORT & Q&A', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
            const Text('Peer-reviewed doubts, instructor answers, and discussions', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
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
// TAB 5: MORE (Profile, Leaderboard, Badges, Logout)
// -----------------------------------------------------------------------------
class _MoreTab extends StatelessWidget {
  final UserModel? user;
  final LeaderboardService leaderboardService;
  final VoidCallback onLogout;

  const _MoreTab({
    this.user,
    required this.leaderboardService,
    required this.onLogout,
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
