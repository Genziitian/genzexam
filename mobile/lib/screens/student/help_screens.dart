import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/app_ux_components.dart';

const _green = Color(0xFF16A34A);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

const supportEmail = 'admin@genziitian.org';
const supportPhoneDisplay = '+91 72549 26179';
const _supportPhoneDial = '+917254926179';
const _supportWhatsApp = '917254926179';

Future<void> _open(BuildContext context, Uri uri, String failMessage) async {
  AppHaptics.light();
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened) messenger.showSnackBar(SnackBar(content: Text(failMessage)));
}

/// Opens the phone's mail app with a new message addressed to support.
Future<void> emailSupport(BuildContext context) {
  final uri = Uri(scheme: 'mailto', path: supportEmail, query: 'subject=${Uri.encodeComponent('Quiz Lab app: help needed')}');
  return _open(context, uri, 'No mail app found. Write to $supportEmail');
}

Future<void> _whatsAppSupport(BuildContext context) {
  return _open(context, Uri.parse('https://wa.me/$_supportWhatsApp'), 'Could not open WhatsApp. Message $supportPhoneDisplay');
}

Future<void> callSupport(BuildContext context) {
  return _open(context, Uri(scheme: 'tel', path: _supportPhoneDial), 'Could not open the dialler. Call $supportPhoneDisplay');
}

// -----------------------------------------------------------------------------
// HELP & SUPPORT sheet: email and phone, each with a button that opens the app
// -----------------------------------------------------------------------------
void showHelpSheet(BuildContext context, {required VoidCallback onOpenFaq}) {
  AppHaptics.selection();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) {
      Widget channel({
        required IconData icon,
        required Color color,
        required String title,
        required String value,
        required List<Widget> actions,
      }) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.28)),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
                        const SizedBox(height: 1),
                        SelectableText(value, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _ink)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: actions),
            ],
          ),
        );
      }

      Widget action(String label, IconData icon, Color color, VoidCallback onTap, {bool filled = true}) {
        return Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled ? color : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 1.3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: filled ? Colors.white : color),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: filled ? Colors.white : color)),
                ],
              ),
            ),
          ),
        );
      }

      return SafeArea(
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
              const Text('Help & Support', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 2),
              const Text('Stuck on something? Reach us directly.', style: TextStyle(fontSize: 13, color: _muted)),
              const SizedBox(height: 16),
              channel(
                icon: Icons.mail_outline_rounded,
                color: _green,
                title: 'Email',
                value: supportEmail,
                actions: [action('Email us', Icons.send_rounded, _green, () => emailSupport(ctx))],
              ),
              channel(
                icon: Icons.phone_in_talk_outlined,
                color: const Color(0xFF0284C7),
                title: 'Phone and WhatsApp',
                value: supportPhoneDisplay,
                actions: [
                  action('WhatsApp', Icons.chat_rounded, const Color(0xFF16A34A), () => _whatsAppSupport(ctx)),
                  const SizedBox(width: 8),
                  action('Call', Icons.call_rounded, const Color(0xFF0284C7), () => callSupport(ctx), filled: false),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(ctx).pop();
                  onOpenFaq();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: const Row(
                    children: [
                      Icon(Icons.quiz_outlined, size: 19, color: _muted),
                      SizedBox(width: 10),
                      Expanded(child: Text('Looking for a quick answer? See the FAQs', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                      Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// -----------------------------------------------------------------------------
// FAQs
// -----------------------------------------------------------------------------
class _Faq {
  final String q;
  final String a;

  const _Faq(this.q, this.a);
}

class _FaqGroup {
  final String title;
  final IconData icon;
  final List<_Faq> items;

  const _FaqGroup(this.title, this.icon, this.items);
}

const List<_FaqGroup> _faqGroups = [
  _FaqGroup('Account and sign-in', Icons.person_outline_rounded, [
    _Faq('How do I sign in?', 'Use "Continue with Google", or type the email and password of your Quiz Lab account. Both lead to the same account if the email matches.'),
    _Faq('I forgot my password. What do I do?', 'Open quiz.genziitian.in in a browser, tap "Forgot password" on the sign-in page and follow the steps. You can also sign in with Google using the same email.'),
    _Faq('How do I change my name or avatar?', 'Go to More and tap your profile card at the top. You can type a new name and pick one of the ready-made avatars, then press "Save changes".'),
    _Faq('Why did I get signed out?', 'Signing in on another device or browser ends the older session. Just sign in again; your papers, scores and XP are safe.'),
    _Faq('How do I delete my account?', 'Go to More, scroll to Legal & Compliance and tap "Delete Account & Data". This removes your account and your attempt records for good.'),
  ]),
  _FaqGroup('Papers and practice', Icons.description_outlined, [
    _Faq('Where do I find papers to attempt?', 'Tap the green lightning button (Practice), pick a course, then choose a paper type such as Quiz 1, Quiz 2, End Term or Mock Test.'),
    _Faq('What shows up in My Papers?', 'Only papers you bought or attempted, with your last score, how many times you tried, and whether an attempt is still in progress.'),
    _Faq('Do I need to claim free papers?', 'No. Free papers open straight away from Practice. Once you start one, it appears in My Papers.'),
    _Faq('Can I attempt a paper more than once?', 'Yes, as many times as you like. Use "Retake" in Practice or "Attempt again" in My Papers. Repeat attempts earn half the XP of a first attempt.'),
    _Faq('What happens if I leave in the middle of a paper?', 'Your answers so far are kept on this phone. The paper shows as "In progress" and you can continue later. On a timed paper the clock keeps running while you are away.'),
    _Faq('What is the difference between timed and untimed papers?', 'An untimed paper lets you take as long as you want. A timed paper starts its clock when you press Start and submits by itself when time runs out.'),
    _Faq('How do I submit a paper?', 'Tap "Submit & Exit" at the top of the paper and confirm. Pressing the phone\'s back button during a paper asks the same question.'),
    _Faq('A question\'s picture is not loading. What now?', 'Check your internet connection and reopen the paper. If the picture is still missing, tell us the paper name and question number by email so we can fix it.'),
  ]),
  _FaqGroup('Scores, XP and ranks', Icons.emoji_events_outlined, [
    _Faq('How do I earn XP?', 'Mainly by finishing papers: 5 XP for finishing plus 1 XP for every 5% you score, and a 10 XP bonus on your first paper of the day. The Rule book (More, under your level) lists every way to earn XP.'),
    _Faq('How do levels and badges work?', 'Your total XP sets your level, and each badge unlocks at a fixed level. Open the Rule book from the More tab to see every level and badge.'),
    _Faq('How is the leaderboard ranked?', 'By total XP. The Ranks tab shows the top students, with the top three on the podium and your own row pinned so you can always see your place.'),
    _Faq('What is the weekly goal?', 'It is the number of quizzes you want to finish from Monday to Sunday. Tap "Change goal" on the Home card to set your own target.'),
    _Faq('What counts as a streak?', 'A streak is the number of days in a row on which you were active. Miss a day and it starts again from one.'),
  ]),
  _FaqGroup('Payments and access', Icons.lock_open_rounded, [
    _Faq('How do I get a paid paper?', 'Paid papers show their price. Buy the paper on quiz.genziitian.in with the same account; it then appears in My Papers here with a "Purchased" tag.'),
    _Faq('I paid but the paper is still locked.', 'Pull down on My Papers to refresh. If it is still locked after a few minutes, email us with your account email and the payment reference.'),
    _Faq('What are Video Solutions?', 'Step-by-step video answers for selected papers, available to Pro members. Open them from More, under Explore.'),
    _Faq('Can I take online proctored exams in the app?', 'No. Proctored exams run only in a desktop browser at quiz.genziitian.in.'),
  ]),
  _FaqGroup('App and settings', Icons.settings_outlined, [
    _Faq('How do I turn on dark mode?', 'Go to More, tap "Theme / Appearance" and choose System, Light or Dark. System follows your phone\'s own setting.'),
    _Faq('Something is not loading.', 'Check your connection, then pull down on the page to refresh. If it keeps happening, close the app fully and open it again.'),
    _Faq('How do I contact support?', 'Go to More and tap "Help & Support Desk" to email or call us directly.'),
  ]),
];

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String _query = '';
  String? _open; // the question that is expanded

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final groups = <_FaqGroup>[];
    for (final g in _faqGroups) {
      final items = query.isEmpty ? g.items : g.items.where((f) => f.q.toLowerCase().contains(query) || f.a.toLowerCase().contains(query)).toList();
      if (items.isNotEmpty) groups.add(_FaqGroup(g.title, g.icon, items));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F5F9),
        surfaceTintColor: const Color(0xFFF1F5F9),
        foregroundColor: _ink,
        elevation: 0,
        titleSpacing: 0,
        title: const Text('FAQs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const Text.rich(
              TextSpan(
                text: 'Quick answers to ',
                children: [TextSpan(text: 'common questions.', style: TextStyle(color: _green))],
              ),
              style: TextStyle(fontSize: 26, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: _ink),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search the FAQs',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                  prefixIcon: Icon(Icons.search_rounded, color: _muted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (groups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('No question matches that. Try other words, or email us.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 14))),
              ),
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 8),
                child: Row(
                  children: [
                    Icon(group.icon, size: 16, color: _green),
                    const SizedBox(width: 7),
                    Text(group.title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: _muted)),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: [
                    for (var i = 0; i < group.items.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      _item(group.items[i]),
                    ],
                  ],
                ),
              ),
            ],
            // Still stuck
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF14532D), Color(0xFF16A34A)]),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Still stuck?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                        SizedBox(height: 2),
                        Text('Write to us and we will help.', style: TextStyle(fontSize: 12.5, color: Color(0xFFD1FAE5))),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => emailSupport(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: const Text('Email us', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(_Faq faq) {
    final open = _open == faq.q;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppHaptics.selection();
        setState(() => _open = open ? null : faq.q);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    faq.q,
                    style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w700, color: open ? const Color(0xFF15803D) : _ink),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: open ? _green : const Color(0xFF94A3B8)),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: open
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8, right: 22),
                      child: Text(faq.a, style: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF475569))),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
