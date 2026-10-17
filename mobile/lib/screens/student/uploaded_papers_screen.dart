import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../api/uploaded_papers_service.dart';
import '../../widgets/app_ux_components.dart';
import '../../widgets/premium_widgets.dart';
import 'native_paper_room.dart';
import 'pro_paywall_screen.dart';

const _ink = Brand.ink;

class UploadedPapersScreen extends StatefulWidget {
  final UserModel user;
  final ApiClient apiClient;

  const UploadedPapersScreen({
    super.key,
    required this.user,
    required this.apiClient,
  });

  @override
  State<UploadedPapersScreen> createState() => _UploadedPapersScreenState();
}

class _UploadedPapersScreenState extends State<UploadedPapersScreen> {
  static const _stages = [
    ('Uploading your file', Icons.cloud_upload_rounded),
    ('Reading the paper', Icons.menu_book_rounded),
    ('Finding the questions', Icons.search_rounded),
    ('Building your test', Icons.auto_awesome_rounded),
  ];

  late final UploadedPapersService _service;
  late Future<UploadedPapersData> _papers;
  bool _uploading = false;
  int _stage = 0;
  Timer? _stageTimer;
  UploadedPaper? _justMade;

  @override
  void initState() {
    super.initState();
    _service = UploadedPapersService(client: widget.apiClient);
    _papers = _service.list();
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _papers = _service.list());
    await _papers;
  }

  Future<void> _pickAndUpload() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'json'],
    );
    if (files.isEmpty || !mounted) return;
    setState(() {
      _uploading = true;
      _stage = 0;
      _justMade = null;
    });
    _stageTimer?.cancel();
    _stageTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _stage < _stages.length - 1) setState(() => _stage++);
    });
    try {
      final paper = await _service.upload(files.single);
      if (!mounted) return;
      AppHaptics.medium();
      setState(() {
        _justMade = paper;
        _papers = _service.list();
      });
    } catch (error) {
      if (!mounted) return;
      AppHaptics.heavy();
      final message = error is ApiException
          ? error.message
          : error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _papers = _service.list());
    } finally {
      _stageTimer?.cancel();
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _open(UploadedPaper paper) async {
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

  Future<void> _goPro() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ProPaywallScreen()),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF1F5F9),
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      title: const Text('Upload a paper'),
    ),
    body: FutureBuilder<UploadedPapersData>(
      future: _papers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_uploading &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Brand.green),
          );
        }
        final papers = snapshot.data?.papers ?? const <UploadedPaper>[];
        final quota = snapshot.data?.quota;
        final isPro = quota?.isPro ?? true;
        final canUpload = quota == null || quota.remaining > 0;
        return RefreshIndicator(
          color: Brand.green,
          edgeOffset: 120,
          onRefresh: _reload,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Hero(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 150),
                      child: _QuotaCard(quota: quota, onGetPro: _goPro),
                    ),
                    const SizedBox(height: 14),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 260),
                      child: _UploadPanel(
                        uploading: _uploading,
                        stage: _stage,
                        stages: _stages,
                        justMade: _justMade,
                        isPro: isPro,
                        canUpload: canUpload,
                        onUpload: _pickAndUpload,
                        onGoPro: _goPro,
                        onOpenMade: _justMade == null
                            ? null
                            : () => _open(_justMade!),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 370),
                      child: _Rules(quota: quota),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Your uploaded papers',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Brand.green.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${papers.length}',
                            style: const TextStyle(
                              color: Brand.green,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (snapshot.hasError)
                      const _MessageCard(
                        text:
                            'Could not load your papers. Pull down to try again.',
                      )
                    else if (papers.isEmpty)
                      const _MessageCard(
                        text:
                            'Your uploaded tests will appear here and in My Papers.',
                      )
                    else
                      for (var i = 0; i < papers.length; i++)
                        FadeSlideIn(
                          delay: Duration(milliseconds: 60 * i.clamp(0, 8)),
                          dy: 16,
                          child: _PaperTile(
                            paper: papers[i],
                            onTap: () => _open(papers[i]),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      22,
      MediaQuery.paddingOf(context).top + 60,
      22,
      26,
    ),
    decoration: const BoxDecoration(
      gradient: Brand.darkGradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
    ),
    child: Row(
      children: [
        Floating(
          distance: 5,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: Brand.gradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Brand.green.withValues(alpha: .45), blurRadius: 26),
              ],
            ),
            child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 38),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: FadeSlideIn(
            delay: Duration(milliseconds: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Turn any paper into a test',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -.4,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'One free upload every week for everyone. Pro members get more.',
                  style: TextStyle(color: Brand.mint, height: 1.4, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Counter shown before any upload: how many are left in the current window.
class _QuotaCard extends StatelessWidget {
  final UploadQuota? quota;
  final VoidCallback onGetPro;
  const _QuotaCard({required this.quota, required this.onGetPro});

  static String _resets(DateTime at) {
    final left = at.difference(DateTime.now());
    if (left.inHours >= 24) return 'in ${left.inDays + 1} days';
    if (left.inHours >= 1) return 'in ${left.inHours} hours';
    return 'in under an hour';
  }

  @override
  Widget build(BuildContext context) {
    final q = quota;
    if (q == null) return const SizedBox.shrink();
    final active = q.remaining > 0;
    final String headline;
    final String detail;
    final free = !q.isPro;
    if (free && q.remaining > 0) {
      headline = '🎁 Your free upload this week';
      detail =
          'Everyone gets ${q.limit} free upload every ${q.windowDays} days. Pro members get ${q.proLimit}.';
    } else if (free) {
      headline = 'Free upload used';
      detail =
          '${q.resetsAt != null ? 'Your next free upload unlocks ${_resets(q.resetsAt!)}. ' : ''}Pro members get ${q.proLimit} every ${q.windowDays} days.';
    } else if (active) {
      headline = '${q.remaining} of ${q.limit} uploads left';
      detail = 'Allowance for any ${q.windowDays} days. You have used ${q.used}.';
    } else {
      headline = 'No uploads left right now';
      detail = q.resetsAt != null
          ? 'Your next upload unlocks ${_resets(q.resetsAt!)}.'
          : 'Please try again later.';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: active ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x0F0F172A), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          AnimatedRing(
            value: q.limit > 0 ? q.remaining / q.limit : 0,
            size: 78,
            stroke: 8,
            color: active ? Brand.green : Brand.gold,
            track: const Color(0x1F64748B),
            child: Text(
              '${q.remaining}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(color: Brand.muted, height: 1.4, fontSize: 13),
                ),
                if (!q.isPro) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      AppHaptics.light();
                      onGetPro();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD36E), Color(0xFFF59E0B)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium_rounded, size: 16, color: Brand.deep),
                          SizedBox(width: 6),
                          Text(
                            'Get Pro',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Brand.deep,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (q.isPro && q.limit > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var i = 0; i < q.limit; i++)
                        Expanded(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 400 + i * 90),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => Container(
                              height: 7,
                              margin: EdgeInsets.only(
                                right: i == q.limit - 1 ? 0 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: (i < q.used
                                        ? const Color(0xFFCBD5E1)
                                        : Brand.green)
                                    .withValues(alpha: v),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The drop target / action area. Swaps between idle, locked, working and done.
class _UploadPanel extends StatelessWidget {
  final bool uploading;
  final int stage;
  final List<(String, IconData)> stages;
  final UploadedPaper? justMade;
  final bool isPro;
  final bool canUpload;
  final VoidCallback onUpload;
  final VoidCallback onGoPro;
  final VoidCallback? onOpenMade;

  const _UploadPanel({
    required this.uploading,
    required this.stage,
    required this.stages,
    required this.justMade,
    required this.isPro,
    required this.canUpload,
    required this.onUpload,
    required this.onGoPro,
    required this.onOpenMade,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: const [
        BoxShadow(color: Color(0x120F172A), blurRadius: 22, offset: Offset(0, 10)),
      ],
    ),
    child: AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, .06),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: uploading
            ? _working()
            : justMade != null
            ? _done()
            : _idle(),
      ),
    ),
  );

  Widget _idle() => Column(
    key: const ValueKey('idle'),
    children: [
      const _Pipeline(),
      const SizedBox(height: 18),
      if (!canUpload && !isPro)
        PremiumButton(
          gold: true,
          icon: Icons.workspace_premium_rounded,
          label: 'Go Pro for more uploads',
          onPressed: onGoPro,
        )
      else
        PremiumButton(
          icon: isPro ? Icons.upload_file_rounded : Icons.card_giftcard_rounded,
          label: !canUpload
              ? 'No uploads left right now'
              : isPro
              ? 'Choose PDF or JSON'
              : 'Claim your free upload',
          onPressed: canUpload ? onUpload : null,
        ),
    ],
  );

  Widget _working() => Column(
    key: const ValueKey('working'),
    children: [
      Floating(
        distance: 4,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: Brand.gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Brand.green.withValues(alpha: .4), blurRadius: 20),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              stages[stage].$2,
              key: ValueKey(stage),
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      for (var i = 0; i < stages.length; i++)
        _StageRow(label: stages[i].$1, state: i < stage ? 2 : (i == stage ? 1 : 0)),
      const SizedBox(height: 14),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (stage + 1) / stages.length),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 8,
            color: Brand.green,
            backgroundColor: const Color(0xFFE2E8F0),
          ),
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'A PDF can take a minute. You can keep this screen open.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Brand.muted, fontSize: 12.5),
      ),
    ],
  );

  Widget _done() => Column(
    key: const ValueKey('done'),
    children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            gradient: Brand.gradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Brand.green.withValues(alpha: .45), blurRadius: 24),
            ],
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'Your test is ready',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink),
      ),
      const SizedBox(height: 4),
      Text(
        '“${justMade!.title}” · ${justMade!.questionCount} questions',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Brand.muted),
      ),
      const SizedBox(height: 4),
      const Text(
        'Skim the questions before you start. AI can make mistakes.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Brand.muted, fontSize: 12.5),
      ),
      const SizedBox(height: 16),
      PremiumButton(
        icon: Icons.play_arrow_rounded,
        label: 'Start the test',
        onPressed: onOpenMade,
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: canUpload ? onUpload : null,
        child: Text(
          canUpload ? 'Upload another paper' : 'No uploads left right now',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _StageRow extends StatelessWidget {
  final String label;
  final int state; // 0 waiting, 1 active, 2 done
  const _StageRow({required this.label, required this.state});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: state == 1 ? const Color(0xFFECFDF3) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: state == 1 ? const Color(0xFFBBF7D0) : Colors.transparent,
      ),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: state == 2
                ? const Icon(
                    Icons.check_circle_rounded,
                    key: ValueKey('d'),
                    color: Brand.green,
                    size: 22,
                  )
                : state == 1
                ? const Padding(
                    key: ValueKey('a'),
                    padding: EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Brand.green,
                    ),
                  )
                : const Icon(
                    Icons.circle_outlined,
                    key: ValueKey('w'),
                    color: Color(0xFFCBD5E1),
                    size: 20,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontWeight: state == 1 ? FontWeight.w800 : FontWeight.w600,
            color: state == 0 ? const Color(0xFF94A3B8) : _ink,
          ),
        ),
      ],
    ),
  );
}

class _Pipeline extends StatelessWidget {
  const _Pipeline();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      _Step(icon: Icons.picture_as_pdf_rounded, label: 'Your PDF', index: 0),
      _Arrow(),
      _Step(icon: Icons.data_object_rounded, label: 'Question data', index: 1),
      _Arrow(),
      _Step(icon: Icons.quiz_rounded, label: 'Your test', index: 2),
    ],
  );
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  const _Step({required this.icon, required this.label, required this.index});

  @override
  Widget build(BuildContext context) => Expanded(
    child: FadeSlideIn(
      delay: Duration(milliseconds: 300 + index * 140),
      child: Column(
        children: [
          Floating(
            distance: 3,
            period: Duration(milliseconds: 2200 + index * 300),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: Brand.gradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Arrow extends StatefulWidget {
  const _Arrow();
  @override
  State<_Arrow> createState() => _ArrowState();
}

class _ArrowState extends State<_Arrow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, child) =>
          Transform.translate(offset: Offset(_c.value * 4 - 2, 0), child: child),
      child: const Icon(
        Icons.arrow_forward_rounded,
        size: 18,
        color: Brand.green,
      ),
    ),
  );
}

class _Rules extends StatelessWidget {
  final UploadQuota? quota;
  const _Rules({required this.quota});

  @override
  Widget build(BuildContext context) {
    final days = quota?.windowDays ?? 7;
    final rules = <(IconData, String, String)>[
      (
        Icons.card_giftcard_rounded,
        'One free upload every $days days',
        'Every account can turn one paper into a test each week.',
      ),
      (
        Icons.workspace_premium_rounded,
        'Pro: ${quota?.proLimit ?? 5} uploads every $days days',
        'The allowance is rolling. A new slot opens $days days after each upload.',
      ),
      (
        Icons.description_rounded,
        'PDF or JSON, up to 10 MB',
        'PDFs can have up to 30 pages. Scanned image PDFs are not supported yet.',
      ),
      (
        Icons.verified_rounded,
        'Failed conversions are free',
        'Only papers that become a test use up an upload.',
      ),
      (
        Icons.lock_rounded,
        'Private to you',
        'Your test appears in My Papers. Our team may review uploads and can add good ones to the public library.',
      ),
      (
        Icons.shield_moon_rounded,
        'Check before you trust',
        'Text from PDFs is sent to DeepSeek AI to structure the questions, and the original PDF is deleted after. AI can make mistakes, so review the questions.',
      ),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload rules',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rules.length; i++)
            FadeSlideIn(
              delay: Duration(milliseconds: 450 + i * 80),
              dy: 12,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Brand.green.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(rules[i].$1, color: Brand.green, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rules[i].$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rules[i].$3,
                            style: const TextStyle(
                              color: Brand.muted,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaperTile extends StatelessWidget {
  final UploadedPaper paper;
  final VoidCallback onTap;
  const _PaperTile({required this.paper, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: () {
          AppHaptics.light();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: Brand.gradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.description_rounded, color: Colors.white),
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
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${paper.questionCount} questions · Your private test',
                      style: const TextStyle(color: Brand.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill_rounded, color: Brand.green, size: 32),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  final String text;
  const _MessageCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Brand.muted, height: 1.4),
    ),
  );
}
