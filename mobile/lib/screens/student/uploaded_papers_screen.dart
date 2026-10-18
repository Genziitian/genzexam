import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../api/uploaded_papers_service.dart';
import '../../widgets/app_ux_components.dart';
import '../../widgets/premium_widgets.dart';
import 'native_paper_room.dart';
import 'pro_membership_card.dart';

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
  late final UploadedPapersService _service;
  late Future<UploadedPapersData> _papers;
  bool _uploading = false;
  UploadedPaper? _justMade;
  bool _rulesVisible = true;

  @override
  void initState() {
    super.initState();
    _service = UploadedPapersService(client: widget.apiClient);
    _papers = _service.list();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _papers = _service.list());
    await _papers;
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    setState(() => _rulesVisible = false);
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'json'],
    );
    if (!mounted) return;
    setState(() => _rulesVisible = true);
    if (files.isEmpty) return;
    setState(() {
      _uploading = true;
      _justMade = null;
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      setState(() => _papers = _service.list());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _open(UploadedPaper paper) async {
    setState(() => _rulesVisible = false);
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
    if (mounted) {
      setState(() => _rulesVisible = true);
      await _reload();
    }
  }

  Future<void> _goPro() async {
    setState(() => _rulesVisible = false);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProMembershipScreen(apiClient: widget.apiClient),
      ),
    );
    if (mounted) {
      setState(() => _rulesVisible = true);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF1F5F9),
    appBar: AppBar(
      backgroundColor: Brand.deep,
      foregroundColor: Colors.white,
      title: const Text('Your uploaded papers'),
    ),
    body: FutureBuilder<UploadedPapersData>(
      future: _papers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Brand.green),
          );
        }
        final papers = [...?snapshot.data?.papers]
          ..sort((a, b) => b.id.compareTo(a.id));
        if (_justMade != null &&
            !papers.any((paper) => paper.id == _justMade!.id)) {
          papers.insert(0, _justMade!);
        }
        final quota = snapshot.data?.quota;
        final canUpload =
            !snapshot.hasError && quota != null && quota.remaining > 0;
        return RefreshIndicator(
          color: Brand.green,
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _QuotaCard(quota: quota, onGetPro: _goPro, onReset: _reload),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your papers (${papers.length})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: canUpload && !_uploading ? _pickAndUpload : null,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Upload paper'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_uploading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Preparing your test… This can take a minute.',
                        ),
                      ),
                    ],
                  ),
                ),
              if (snapshot.hasError)
                const _MessageCard(
                  text: 'Could not load your papers. Pull down to try again.',
                )
              else if (papers.isEmpty && !_uploading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 42,
                        color: Brand.green,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your papers will appear here',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Turn a PDF or JSON into a practice test.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: canUpload ? _pickAndUpload : null,
                        child: const Text('Upload your first paper'),
                      ),
                    ],
                  ),
                )
              else
                for (final paper in papers)
                  _PaperTile(paper: paper, onTap: () => _open(paper)),
              const SizedBox(height: 16),
              if (_rulesVisible) _Rules(quota: quota),
            ],
          ),
        );
      },
    ),
  );
}

class _QuotaCard extends StatefulWidget {
  final UploadQuota? quota;
  final VoidCallback onGetPro;
  final VoidCallback onReset;
  const _QuotaCard({
    required this.quota,
    required this.onGetPro,
    required this.onReset,
  });
  @override
  State<_QuotaCard> createState() => _QuotaCardState();
}

class _QuotaCardState extends State<_QuotaCard> {
  Timer? _ticker;
  bool _refreshRequested = false;
  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || widget.quota?.remaining != 0) return;
      final reset = widget.quota?.resetsAt;
      if (reset != null &&
          !reset.isAfter(DateTime.now()) &&
          !_refreshRequested) {
        _refreshRequested = true;
        widget.onReset();
      }
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _QuotaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quota?.resetsAt != widget.quota?.resetsAt ||
        widget.quota?.remaining != 0)
      _refreshRequested = false;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _remaining(DateTime at) {
    final duration = at.difference(DateTime.now());
    if (duration.isNegative) return 'Checking availability…';
    return '${duration.inDays}d ${duration.inHours % 24}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s';
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quota;
    if (q == null) return const SizedBox.shrink();
    final text = q.remaining > 0
        ? (q.isPro
              ? '${q.remaining} of ${q.limit} uploads available'
              : '${q.remaining} free upload available')
        : (q.resetsAt != null
              ? 'Next ${q.isPro ? 'upload' : 'free upload'}: ${_remaining(q.resetsAt!)}'
              : 'Upload allowance used');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Brand.muted, fontSize: 13),
            ),
          ),
          if (!q.isPro)
            TextButton(
              onPressed: widget.onGetPro,
              child: Text(
                q.remaining > 0
                    ? 'Get ${q.proLimit} · Pro'
                    : 'Get Pro to upload',
              ),
            ),
        ],
      ),
    );
  }
}

class _Rules extends StatefulWidget {
  final UploadQuota? quota;
  const _Rules({required this.quota});

  @override
  State<_Rules> createState() => _RulesState();
}

class _RulesState extends State<_Rules> with WidgetsBindingObserver {
  bool _expanded = false;
  Timer? _collapseTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _expanded) {
      _collapseTimer?.cancel();
      setState(() => _expanded = false);
    }
  }

  void _toggle() {
    _collapseTimer?.cancel();
    setState(() => _expanded = !_expanded);
    if (_expanded)
      _collapseTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() => _expanded = false);
      });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quota = widget.quota;
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
          TextButton.icon(
            onPressed: _toggle,
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(
              _expanded ? 'Upload rules · See less' : 'Upload rules · See all',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          if (_expanded) const SizedBox(height: 12),
          for (var i = 0; i < (_expanded ? rules.length : 0); i++)
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
                child: const Icon(
                  Icons.description_rounded,
                  color: Colors.white,
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
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${paper.questionCount} questions · Your private test',
                      style: const TextStyle(
                        color: Brand.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Brand.green,
                size: 32,
              ),
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
