import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../api/uploaded_papers_service.dart';
import '../../widgets/app_ux_components.dart';
import '../../widgets/premium_widgets.dart';
import '../../widgets/feature_load_error_card.dart';
import 'help_screens.dart';
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

class _UploadedPapersScreenState extends State<UploadedPapersScreen>
    with WidgetsBindingObserver {
  late final UploadedPapersService _service;
  late Future<UploadedPapersData> _papers;
  bool _picking = false;
  bool _uploading = false;
  UploadedPaper? _justMade;
  UploadedPapersData? _lastLoaded;
  bool _rulesVisible = true;
  Timer? _refreshTimer;
  bool _refreshing = false;
  int _dataVersion = 0;

  @override
  void initState() {
    super.initState();
    _service = UploadedPapersService(client: widget.apiClient);
    _papers = _service.list();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshVisible(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshVisible();
  }

  Future<void> _refreshVisible() async {
    if (!mounted ||
        _picking ||
        _uploading ||
        _refreshing ||
        ModalRoute.of(context)?.isCurrent != true ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
      return;
    _refreshing = true;
    final version = _dataVersion;
    try {
      final data = await _service.list();
      if (mounted && !_picking && !_uploading && version == _dataVersion)
        setState(() {
          _papers = Future.value(data);
        });
    } catch (_) {
      /* Keep the last successful screen; explicit refresh reports errors. */
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _reload() async {
    if (!mounted || _picking || _uploading) return;
    _dataVersion++;
    setState(() {
      _papers = _service.list();
    });
    try {
      await _papers;
    } catch (_) {
      // The FutureBuilder renders this failure; refresh must still finish.
    }
  }

  Future<void> _pickAndUpload() async {
    if (_picking || _uploading) return;
    setState(() {
      _dataVersion++;
      _picking = true;
      _rulesVisible = false;
    });
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'json'],
      );
      if (!mounted || files.isEmpty) return;
      if (files.length != 1) {
        throw const ApiException(message: 'Choose one paper at a time.');
      }
      setState(() {
        _picking = false;
        _uploading = true;
        _rulesVisible = true;
      });
      final paper = await _service.upload(files.single);
      if (!mounted) return;
      AppHaptics.medium();
      setState(() {
        _justMade = paper;
      });
    } catch (error) {
      if (!mounted) return;
      AppHaptics.heavy();
      final message = error is ApiException
          ? error.message
          : _picking
          ? 'Could not choose a file. Please try again.'
          : 'Could not upload your paper. Please try again.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        final refreshAllowance = _uploading;
        setState(() {
          _picking = false;
          _uploading = false;
          _rulesVisible = true;
        });
        // A rejected/uncertain upload may have changed the server allowance.
        // Await refresh so a failed GET is handled even before the next frame.
        if (refreshAllowance) await _reload();
      }
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
      title: const Text('Upload a paper'),
    ),
    body: FutureBuilder<UploadedPapersData>(
      future: _papers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            _lastLoaded == null) {
          return const Center(
            child: CircularProgressIndicator(color: Brand.green),
          );
        }
        if (snapshot.hasData) _lastLoaded = snapshot.data;
        final data = snapshot.data ?? _lastLoaded;
        final papers = [...?data?.papers]..sort((a, b) => b.id.compareTo(a.id));
        if (_justMade != null &&
            !papers.any((paper) => paper.id == _justMade!.id)) {
          papers.insert(0, _justMade!);
        }
        final quota = data?.quota;
        final freeRemaining = quota?.remaining ?? 0;
        final canUpload =
            snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError &&
            quota != null &&
            quota.remaining > 0;
        return RefreshIndicator(
          color: Brand.green,
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const _UploadGuide(),
              const SizedBox(height: 12),
              if (quota == null || snapshot.hasError) ...[
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Upload paper'),
                ),
                const SizedBox(height: 12),
              ],
              if (canUpload && quota.isPro != true) ...[
                FilledButton.icon(
                  onPressed: !_picking && !_uploading ? _pickAndUpload : null,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(
                    'Claim $freeRemaining free upload${freeRemaining == 1 ? '' : 's'}',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!snapshot.hasError)
                _QuotaCard(quota: quota, onGetPro: _goPro, onReset: _reload),
              if (canUpload && quota.isPro == true) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: !_picking && !_uploading ? _pickAndUpload : null,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Upload paper'),
                ),
              ],
              const SizedBox(height: 22),
              Text(
                data == null ? 'Your papers' : 'Your papers (${papers.length})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
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
                FeatureLoadErrorCard(
                  error: snapshot.error!,
                  feature: 'Your papers',
                  onRetry: _reload,
                  onSupport: () => emailSupport(context),
                  showingSavedData: _lastLoaded != null,
                ),
              if (!snapshot.hasError && papers.isEmpty && !_uploading)
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
                      Text(
                        canUpload
                            ? 'Use the upload button above to turn a PDF or JSON into a test.'
                            : quota == null
                            ? 'Upload allowance could not be loaded. Pull down to retry.'
                            : 'Your next upload countdown is shown above. Existing tests remain available here.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else if (papers.isNotEmpty)
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

class _UploadGuide extends StatelessWidget {
  const _UploadGuide();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How it works',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        SizedBox(height: 14),
        Row(
          children: [
            _GuideStep(icon: Icons.upload_file_rounded, label: 'Upload'),
            Icon(Icons.arrow_forward_rounded, size: 18, color: Brand.green),
            _GuideStep(icon: Icons.auto_awesome_rounded, label: 'Convert'),
            Icon(Icons.arrow_forward_rounded, size: 18, color: Brand.green),
            _GuideStep(
              icon: Icons.play_circle_fill_rounded,
              label: 'Take test',
            ),
          ],
        ),
      ],
    ),
  );
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: Brand.green, size: 30),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
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
    final available = q.remaining > 0;
    final headline = q.isPro
        ? '${q.remaining} of ${q.limit} Pro uploads available'
        : available
        ? '${q.remaining} free upload available'
        : 'Free upload used';
    final bannerOnly = !q.isPro && available;
    return Container(
      padding: bannerOnly
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerOnly ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (q.isPro && available)
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Brand.green.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Brand.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pro uploads available',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Brand.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: q.limit > 0 ? q.remaining / q.limit : 0,
                          minHeight: 6,
                          color: Brand.green,
                          backgroundColor: Brand.green.withValues(alpha: .15),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text.rich(
                  TextSpan(
                    text: '${q.remaining}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                    children: [
                      TextSpan(
                        text: ' / ${q.limit}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Brand.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          if (q.isPro && !available || !q.isPro && !available)
            Text(
              headline,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          if (!available)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                q.resetsAt != null
                    ? 'Next ${q.isPro ? 'upload' : 'free upload'} in ${_remaining(q.resetsAt!)}'
                    : 'Refresh to check your next upload.',
                style: const TextStyle(color: Brand.muted, fontSize: 13),
              ),
            ),
          if (!q.isPro)
            Container(
              margin: EdgeInsets.only(top: available ? 0 : 12),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFF7DD), Color(0xFFFFE7A8)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF2C75B)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33D4A017),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Brand.deep,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Color(0xFFFFD36E),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${q.proLimit} uploads every ${q.windowDays} days with Pro',
                      style: const TextStyle(
                        color: Color(0xFF5B3A00),
                        fontSize: 13.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Brand.deep,
                      foregroundColor: const Color(0xFFFFD36E),
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: widget.onGetPro,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Get Pro',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Upload rules',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _toggle,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                iconAlignment: IconAlignment.end,
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_expanded ? 'See less' : 'See all'),
              ),
            ],
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
