import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../widgets/app_ux_components.dart';

const _green = Color(0xFF16A34A);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

String _timeAgo(DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}mo ago';
  return '${diff.inDays ~/ 365}y ago';
}

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

const _avatarColors = [
  Color(0xFF16A34A),
  Color(0xFF7C3AED),
  Color(0xFFD97706),
  Color(0xFFDC2626),
  Color(0xFF0284C7),
  Color(0xFFDB2777),
];

Widget _authorAvatar(DiscussionAuthor author, double size) {
  final color = author.isAnonymous ? const Color(0xFF64748B) : _avatarColors[author.name.hashCode.abs() % _avatarColors.length];
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
    ),
    child: author.isAnonymous
        ? Icon(Icons.person_outline_rounded, size: size * 0.55, color: color)
        : Text(_initialsOf(author.name), style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w800, color: color)),
  );
}

Widget _pill(String text, Color color, {IconData? icon}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 3)],
        Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// DISCUSSIONS: list with search and filters, ask a doubt, open a thread
// -----------------------------------------------------------------------------
class DiscussionsScreen extends StatefulWidget {
  final DiscussionService discussionService;

  const DiscussionsScreen({super.key, required this.discussionService});

  @override
  State<DiscussionsScreen> createState() => _DiscussionsScreenState();
}

class _DiscussionsScreenState extends State<DiscussionsScreen> {
  // label -> (sort, mine)
  static const _filters = ['Newest', 'Trending', 'Unsolved', 'Solved', 'My doubts'];

  bool _loading = true;
  String? _error;
  List<DiscussionListItem> _items = [];
  int _filter = 0;
  String _search = '';
  Timer? _searchDebounce;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    final request = ++_request;
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final sort = const ['newest', 'trending', 'unsolved', 'solved', 'newest'][_filter];
      final items = await widget.discussionService.getDiscussions(
        sort: sort,
        search: _search,
        mine: _filter == 4 ? true : null,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load discussions. Check your connection.';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _search = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _load());
  }

  Future<void> _openThread(DiscussionListItem item) async {
    AppHaptics.light();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiscussionThreadScreen(discussionService: widget.discussionService, discussionId: item.id, title: item.title),
      ),
    );
    if (mounted) _load(quiet: true);
  }

  Future<void> _ask() async {
    AppHaptics.light();
    final createdId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => _AskDoubtSheet(discussionService: widget.discussionService),
    );
    if (createdId == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your doubt is posted.')));
    setState(() => _filter = 0);
    _load();
  }

  Widget _card(DiscussionListItem d) {
    return GestureDetector(
      onTap: () => _openThread(d),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: d.isSolved ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: _ink.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _authorAvatar(d.author, 30),
                const SizedBox(width: 9),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: d.author.isAnonymous ? 'Anonymous' : d.author.name,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink),
                      children: [
                        if (d.isMine) const TextSpan(text: '  (you)', style: TextStyle(fontWeight: FontWeight.w500, color: _green)),
                        TextSpan(
                          text: '  ·  ${_timeAgo(d.createdAt)}',
                          style: const TextStyle(fontWeight: FontWeight.w400, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (d.isSolved) _pill('Solved', _green, icon: Icons.check_circle_rounded),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              d.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w700, color: _ink),
            ),
            if (d.bodyPreview.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                d.bodyPreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.4, color: _muted),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (d.subjectLabel != null && d.subjectLabel!.isNotEmpty) ...[
                  Flexible(child: _pill(d.subjectLabel!, const Color(0xFF2563EB))),
                  const SizedBox(width: 6),
                ] else if (d.course != null) ...[
                  Flexible(child: _pill(d.course!.name, const Color(0xFF2563EB))),
                  const SizedBox(width: 6),
                ],
                const Spacer(),
                Icon(d.myVote ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, size: 14, color: d.myVote ? _green : _muted),
                const SizedBox(width: 4),
                Text('${d.voteCount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
                const SizedBox(width: 12),
                const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: _muted),
                const SizedBox(width: 4),
                Text('${d.replyCount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
                const SizedBox(width: 12),
                const Icon(Icons.visibility_outlined, size: 14, color: _muted),
                const SizedBox(width: 4),
                Text('${d.viewCount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    final searching = _search.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFDCFCE7), Color(0xFFBBF7D0)]),
            ),
            child: const Icon(Icons.forum_rounded, size: 38, color: _green),
          ),
          const SizedBox(height: 16),
          Text(
            searching
                ? 'Nothing matches your search'
                : _filter == 4
                    ? 'You have not asked anything yet'
                    : 'No discussions here yet',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 6),
          Text(
            searching ? 'Try different words, or ask it as a new doubt.' : 'Stuck on a question? Ask it here and other students can help.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, height: 1.4, color: _muted),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _ask,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF15803D)]),
                boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 7))],
              ),
              child: const Text('Ask the first doubt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ask,
        backgroundColor: _green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text('Ask doubt', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(quiet: true),
          color: _green,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  const SizedBox(width: 4),
                  const Text('DISCUSSIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.2, color: _muted)),
                ],
              ),
              const SizedBox(height: 6),
              const Text.rich(
                TextSpan(
                  text: 'Ask, answer, ',
                  children: [TextSpan(text: 'learn together.', style: TextStyle(color: _green))],
                ),
                style: TextStyle(fontSize: 28, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: _ink),
              ),
              const SizedBox(height: 14),

              // Search
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search doubts',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                    prefixIcon: Icon(Icons.search_rounded, color: _muted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < _filters.length; i++)
                      GestureDetector(
                        onTap: () {
                          if (_filter == i) return;
                          AppHaptics.selection();
                          setState(() => _filter = i);
                          _load();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _filter == i ? _green : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _filter == i ? _green : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            _filters[i],
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _filter == i ? Colors.white : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_loading)
                AppShimmerCard.list(count: 4)
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 14)),
                      const SizedBox(height: 10),
                      TextButton(onPressed: _load, child: const Text('Try again', style: TextStyle(color: _green, fontWeight: FontWeight.bold))),
                    ],
                  ),
                )
              else if (_items.isEmpty)
                _emptyState()
              else
                for (final d in _items) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(d)),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ASK A DOUBT
// -----------------------------------------------------------------------------
class _AskDoubtSheet extends StatefulWidget {
  final DiscussionService discussionService;

  const _AskDoubtSheet({required this.discussionService});

  @override
  State<_AskDoubtSheet> createState() => _AskDoubtSheetState();
}

class _AskDoubtSheetState extends State<_AskDoubtSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  Map<String, String> _subjects = {};
  String? _subject;
  bool _anonymous = false;
  bool _posting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.discussionService.getSubjects().then((subjects) {
      if (mounted) setState(() => _subjects = subjects);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.length < 5) {
      setState(() => _error = 'Give your doubt a short title (at least 5 letters).');
      return;
    }
    if (body.isEmpty) {
      setState(() => _error = 'Describe your doubt so others can help.');
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      final id = await widget.discussionService.createDiscussion(title: title, body: body, subject: _subject, isAnonymous: _anonymous);
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _error = e is ApiException ? e.message : 'Could not post your doubt. Please try again.';
      });
    }
  }

  InputDecoration _field(String hint) {
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      counterText: '',
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: border(const Color(0xFFE2E8F0)),
      enabledBorder: border(const Color(0xFFE2E8F0)),
      focusedBorder: border(_green, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Ask a doubt', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 2),
              const Text('A clear title gets faster answers.', style: TextStyle(fontSize: 13, color: _muted)),
              const SizedBox(height: 16),
              TextField(controller: _title, maxLength: 200, textCapitalization: TextCapitalization.sentences, decoration: _field('Title, e.g. How do I find the vertex?')),
              const SizedBox(height: 10),
              TextField(
                controller: _body,
                maxLength: 5000,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: _field('Explain what you tried and where you got stuck'),
              ),
              if (_subjects.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('SUBJECT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: Color(0xFF94A3B8))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in _subjects.entries)
                      GestureDetector(
                        onTap: () {
                          AppHaptics.selection();
                          setState(() => _subject = _subject == entry.key ? null : entry.key);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _subject == entry.key ? _green : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _subject == entry.key ? _green : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            entry.value,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _subject == entry.key ? Colors.white : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.visibility_off_outlined, size: 18, color: _muted),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Post anonymously', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                  Switch(value: _anonymous, activeTrackColor: _green, onChanged: (v) => setState(() => _anonymous = v)),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _posting ? null : _post,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _posting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text('Post doubt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ONE THREAD: the doubt, its replies, upvotes and a reply box
// -----------------------------------------------------------------------------
class DiscussionThreadScreen extends StatefulWidget {
  final DiscussionService discussionService;
  final int discussionId;
  final String title;

  const DiscussionThreadScreen({super.key, required this.discussionService, required this.discussionId, required this.title});

  @override
  State<DiscussionThreadScreen> createState() => _DiscussionThreadScreenState();
}

class _DiscussionThreadScreenState extends State<DiscussionThreadScreen> {
  DiscussionDetail? _thread;
  String? _error;
  final _reply = TextEditingController();
  bool _sending = false;
  // Local overrides after an upvote, so the screen reacts at once.
  bool? _myVote;
  int? _voteCount;
  final Map<int, VoteResult> _replyVotes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final thread = await widget.discussionService.getDiscussion(widget.discussionId);
      if (!mounted) return;
      setState(() {
        _thread = thread;
        _error = null;
        _myVote = null;
        _voteCount = null;
        _replyVotes.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : 'Could not load this discussion.');
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _voteThread() async {
    AppHaptics.selection();
    try {
      final result = await widget.discussionService.voteDiscussion(widget.discussionId);
      if (mounted) {
        setState(() {
          _myVote = result.voted;
          _voteCount = result.count;
        });
      }
    } catch (e) {
      _toast(e is ApiException ? e.message : 'Could not register your vote.');
    }
  }

  Future<void> _voteReply(DiscussionReplyModel reply) async {
    AppHaptics.selection();
    try {
      final result = await widget.discussionService.voteReply(reply.id);
      if (mounted) setState(() => _replyVotes[reply.id] = result);
    } catch (e) {
      _toast(e is ApiException ? e.message : 'Could not register your vote.');
    }
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await widget.discussionService.replyToDiscussion(discussionId: widget.discussionId, body: body);
      _reply.clear();
      await _load();
    } catch (e) {
      _toast(e is ApiException ? e.message : 'Could not post your reply.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _voteButton({required bool voted, required int count, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: voted ? _green.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: voted ? _green.withValues(alpha: 0.45) : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(voted ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, size: 15, color: voted ? _green : _muted),
            const SizedBox(width: 5),
            Text('$count', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: voted ? _green : _muted)),
          ],
        ),
      ),
    );
  }

  Widget _authorLine(DiscussionAuthor author, DateTime? time, {bool mine = false}) {
    return Row(
      children: [
        _authorAvatar(author, 32),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      author.isAnonymous ? 'Anonymous' : author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                    ),
                  ),
                  if (author.isAdmin) ...[const SizedBox(width: 6), _pill('Team', const Color(0xFF7C3AED))],
                  if (mine) ...[const SizedBox(width: 6), _pill('You', _green)],
                ],
              ),
              Text(_timeAgo(time), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _replyCard(DiscussionReplyModel reply) {
    final vote = _replyVotes[reply.id];
    final highlighted = reply.isAccepted || reply.isEndorsed;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: reply.isAccepted ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlighted ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlighted) ...[
            Row(
              children: [
                if (reply.isAccepted) _pill('Accepted answer', _green, icon: Icons.check_circle_rounded),
                if (reply.isAccepted && reply.isEndorsed) const SizedBox(width: 6),
                if (reply.isEndorsed) _pill('Endorsed', const Color(0xFF7C3AED), icon: Icons.verified_rounded),
              ],
            ),
            const SizedBox(height: 10),
          ],
          _authorLine(reply.author, reply.createdAt, mine: reply.isMine),
          const SizedBox(height: 10),
          SelectableText(reply.body, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF1E293B))),
          const SizedBox(height: 10),
          _voteButton(voted: vote?.voted ?? reply.myVote, count: vote?.count ?? reply.voteCount, onTap: () => _voteReply(reply)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thread = _thread;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F5F9),
        surfaceTintColor: const Color(0xFFF1F5F9),
        foregroundColor: _ink,
        elevation: 0,
        titleSpacing: 0,
        title: const Text('Discussion', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      ),
      body: thread == null
          ? (_error != null
              ? AppErrorCard(title: 'Unable to Load Discussion', message: _error!, onRetry: _load)
              : AppShimmerCard.list(count: 3))
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    color: _green,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        // The doubt
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [BoxShadow(color: _ink.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 8))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (thread.isSolved) _pill('Solved', _green, icon: Icons.check_circle_rounded),
                                  if (thread.subjectLabel != null && thread.subjectLabel!.isNotEmpty) _pill(thread.subjectLabel!, const Color(0xFF2563EB)),
                                  if (thread.course != null) _pill(thread.course!.name, const Color(0xFF0284C7)),
                                  if (thread.linkedQuiz != null) _pill(thread.linkedQuiz!.title, const Color(0xFFD97706), icon: Icons.description_outlined),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(thread.title, style: const TextStyle(fontSize: 19, height: 1.3, fontWeight: FontWeight.w800, color: _ink)),
                              const SizedBox(height: 12),
                              _authorLine(thread.author, thread.createdAt, mine: thread.isMine),
                              const SizedBox(height: 12),
                              SelectableText(thread.body, style: const TextStyle(fontSize: 14.5, height: 1.55, color: Color(0xFF1E293B))),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  _voteButton(voted: _myVote ?? thread.myVote, count: _voteCount ?? thread.voteCount, onTap: _voteThread),
                                  const Spacer(),
                                  const Icon(Icons.visibility_outlined, size: 14, color: _muted),
                                  const SizedBox(width: 4),
                                  Text('${thread.viewCount} views', style: const TextStyle(fontSize: 12, color: _muted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          thread.replies.isEmpty
                              ? 'NO REPLIES YET'
                              : '${thread.replies.length} ${thread.replies.length == 1 ? 'REPLY' : 'REPLIES'}',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 10),
                        if (thread.replies.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 22),
                            child: Center(
                              child: Text('Be the first to help. Write a reply below.', style: TextStyle(fontSize: 13.5, color: _muted)),
                            ),
                          )
                        else
                          for (final reply in thread.replies) _replyCard(reply),
                      ],
                    ),
                  ),
                ),

                // Reply box
                Container(
                  padding: EdgeInsets.fromLTRB(12, 8, 8, 8 + MediaQuery.of(context).viewPadding.bottom),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Write a reply',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _send,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                          child: _sending
                              ? const Padding(
                                  padding: EdgeInsets.all(11),
                                  child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                )
                              : const Icon(Icons.send_rounded, size: 19, color: Colors.white),
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
