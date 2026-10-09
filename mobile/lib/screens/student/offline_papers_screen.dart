import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../api/offline_paper_store.dart';
import 'native_paper_room.dart';

const _green = Color(0xFF16A34A);
const _ink = Color(0xFF0F172A);

/// Lists only this student's encrypted, on-device paper copies.
class OfflinePapersScreen extends StatefulWidget {
  final UserModel user;
  final ApiClient apiClient;

  const OfflinePapersScreen({
    super.key,
    required this.user,
    required this.apiClient,
  });

  @override
  State<OfflinePapersScreen> createState() => _OfflinePapersScreenState();
}

class _OfflinePapersScreenState extends State<OfflinePapersScreen> {
  late Future<List<QuizDetail>> _papers;

  @override
  void initState() {
    super.initState();
    _papers = OfflinePaperStore.listDownloadedPapers(widget.user.id);
  }

  Future<void> _reload() async {
    setState(() {
      _papers = OfflinePaperStore.listDownloadedPapers(widget.user.id);
    });
    await _papers;
  }

  Future<void> _open(QuizDetail paper) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PaperRoomScreen(
          quizId: paper.id,
          title: paper.title,
          apiClient: widget.apiClient,
          user: widget.user,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Offline papers'),
        backgroundColor: const Color(0xFFF1F5F9),
        foregroundColor: _ink,
      ),
      body: FutureBuilder<List<QuizDetail>>(
        future: _papers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _green),
            );
          }
          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load downloads',
              message: 'Your saved papers are still on this device. Try again.',
              action: TextButton(
                onPressed: _reload,
                child: const Text('Try again'),
              ),
            );
          }

          final papers = snapshot.data ?? const <QuizDetail>[];
          if (papers.isEmpty) {
            return _EmptyState(
              icon: Icons.download_for_offline_outlined,
              title: 'No offline papers yet',
              message:
                  'Open Practice while online, then tap the download icon beside a paper. It will appear here for offline practice.',
              action: const SizedBox.shrink(),
            );
          }

          return RefreshIndicator(
            color: _green,
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, color: _green, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Saved privately inside Quiz LAB on this device. These papers are not exported as files.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${papers.length} ${papers.length == 1 ? 'paper' : 'papers'} ready offline',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                for (final paper in papers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => _open(paper),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                  Icons.description_outlined,
                                  color: _green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      paper.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: _ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${paper.course?.name ?? 'Practice'} · ${paper.questions.length} questions',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.play_circle_fill_rounded,
                                color: _green,
                                size: 30,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: _green),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.45, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          action,
        ],
      ),
    ),
  );
}
