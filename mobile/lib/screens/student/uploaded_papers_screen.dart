import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../api/uploaded_papers_service.dart';
import 'native_paper_room.dart';

const _green = Color(0xFF16A34A);
const _ink = Color(0xFF0F172A);

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
  late Future<List<UploadedPaper>> _papers;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _service = UploadedPapersService(client: widget.apiClient);
    _papers = _service.list();
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
    setState(() => _uploading = true);
    try {
      final paper = await _service.upload(files.single);
      if (!mounted) return;
      setState(() => _papers = _service.list());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '“${paper.title}” is ready with ${paper.questionCount} questions.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF1F5F9),
    appBar: AppBar(
      title: const Text('Upload a paper'),
      backgroundColor: const Color(0xFFF1F5F9),
      foregroundColor: _ink,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1CC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(
                  color: Color(0xFF9A5B00),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    body: FutureBuilder<List<UploadedPaper>>(
      future: _papers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_uploading) {
          return const Center(child: CircularProgressIndicator(color: _green));
        }
        final papers = snapshot.data ?? const <UploadedPaper>[];
        return RefreshIndicator(
          color: _green,
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              _HowItWorks(uploading: _uploading, onUpload: _pickAndUpload),
              const SizedBox(height: 22),
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
                  Text(
                    '${papers.length}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (snapshot.hasError)
                _MessageCard(
                  text: 'Could not load your papers. Pull down to try again.',
                )
              else if (papers.isEmpty)
                const _MessageCard(
                  text:
                      'Your uploaded tests will appear here and in My Papers.',
                )
              else
                for (final paper in papers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => _open(paper),
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFDCFCE7),
                            child: Icon(
                              Icons.description_rounded,
                              color: _green,
                            ),
                          ),
                          title: Text(
                            paper.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          subtitle: Text(
                            '${paper.questionCount} questions · Your private test',
                          ),
                          trailing: const Icon(
                            Icons.play_circle_fill_rounded,
                            color: _green,
                            size: 30,
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

class _HowItWorks extends StatelessWidget {
  final bool uploading;
  final VoidCallback onUpload;
  const _HowItWorks({required this.uploading, required this.onUpload});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFDDE7F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Turn a paper into a practice test',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Upload a PDF or question JSON. We extract the questions, organize them, and create a private test for you.',
          style: TextStyle(height: 1.45, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 18),
        const Row(
          children: [
            _Step(icon: Icons.picture_as_pdf_rounded, label: 'Your PDF'),
            _Arrow(),
            _Step(icon: Icons.data_object_rounded, label: 'Question data'),
            _Arrow(),
            _Step(icon: Icons.quiz_rounded, label: 'Your test'),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'We send selectable text from PDFs to DeepSeek AI to structure the questions. The original PDF is deleted after processing; the generated test stays in your account. Please review the questions before starting. Scanned PDFs are not supported yet.',
          style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: uploading ? null : onUpload,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(
              uploading ? 'Creating your test…' : 'Choose PDF or JSON',
            ),
          ),
        ),
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Step({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: const BoxDecoration(
            color: Color(0xFFECFDF3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _green, size: 21),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ],
    ),
  );
}

class _Arrow extends StatelessWidget {
  const _Arrow();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 17),
    child: Icon(
      Icons.arrow_forward_rounded,
      size: 16,
      color: Color(0xFF94A3B8),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  final String text;
  const _MessageCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
    ),
  );
}
