import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../api/api.dart';
import 'pro_membership_card.dart';

/// Native catalog and navigation. Only the provider's protected video surface
/// uses its existing signed player; no Quiz LAB website or web session is loaded.
class VideoSolutionsScreen extends StatefulWidget {
  final ApiClient apiClient;
  final UserModel? user;
  const VideoSolutionsScreen({super.key, required this.apiClient, this.user});
  @override
  State<VideoSolutionsScreen> createState() => _VideoSolutionsScreenState();
}

class _VideoSolutionsScreenState extends State<VideoSolutionsScreen> {
  List<Map<String, dynamic>>? _videos;
  String? _error;
  String _query = '';
  String? _course;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await widget.apiClient.get<List<dynamic>>(
        '/video-solutions',
      );
      if (mounted)
        setState(() {
          _videos = (response.data ?? [])
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
          _error = null;
        });
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Could not load videos. Please try again.',
        );
    }
  }

  Future<void> _play(Map<String, dynamic> video) async {
    if (_opening) return;
    if (video['locked'] == true) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProMembershipScreen(apiClient: widget.apiClient),
        ),
      );
      await _load();
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final response = await widget.apiClient.get<Map<String, dynamic>>(
        '/video-solutions/${video['id']}/play',
      );
      final uri = Uri.tryParse(response.data?['embed_src'] as String? ?? '');
      final apiOrigin = Uri.parse(widget.apiClient.dio.options.baseUrl);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != apiOrigin.host ||
          !uri.path.contains('/video-solutions/embed/')) {
        throw const ApiException(
          message: 'The server returned an invalid video source.',
        );
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ProtectedVideoScreen(uri: uri, video: video),
        ),
      );
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Could not open the video. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = <String>{
      for (final video in _videos ?? <Map<String, dynamic>>[])
        if (video['course'] is Map) (video['course'] as Map)['name'] as String,
    }.toList()..sort();
    final videos = (_videos ?? [])
        .where(
          (v) =>
              (_course == null || (v['course'] as Map?)?['name'] == _course) &&
              '${v['title']} ${v['description'] ?? ''} ${v['author'] ?? ''}'
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Video Solutions')),
      body: _videos == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search videos',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All courses'),
                        selected: _course == null,
                        onSelected: (_) => setState(() => _course = null),
                      ),
                      for (final course in courses)
                        ChoiceChip(
                          label: Text(course),
                          selected: _course == course,
                          onSelected: (_) => setState(() => _course = course),
                        ),
                    ],
                  ),
                  if (_error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(_error!),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_opening) const LinearProgressIndicator(),
                  if (_videos != null && videos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: Text('No videos found.')),
                    ),
                  for (final video in videos)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _opening ? null : () => _play(video),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((video['thumbnail_url'] as String?)
                                    ?.isNotEmpty ==
                                true)
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Image.network(
                                  video['thumbnail_url'] as String,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(
                                      Icons.ondemand_video_rounded,
                                      size: 48,
                                    ),
                                  ),
                                ),
                              ),
                            ListTile(
                              leading: Icon(
                                video['locked'] == true
                                    ? Icons.lock_outline_rounded
                                    : Icons.play_circle_outline_rounded,
                              ),
                              title: Text(
                                video['title'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  if (video['course'] is Map)
                                    (video['course'] as Map)['name'],
                                  if ((video['author'] as String?)
                                          ?.isNotEmpty ==
                                      true)
                                    video['author'],
                                  if ((video['duration'] as String?)
                                          ?.isNotEmpty ==
                                      true)
                                    video['duration'],
                                ].join(' · '),
                              ),
                              trailing: video['is_pro'] == true
                                  ? const Chip(label: Text('PRO'))
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ProtectedVideoScreen extends StatefulWidget {
  final Uri uri;
  final Map<String, dynamic> video;
  const _ProtectedVideoScreen({required this.uri, required this.video});
  @override
  State<_ProtectedVideoScreen> createState() => _ProtectedVideoScreenState();
}

class _ProtectedVideoScreenState extends State<_ProtectedVideoScreen> {
  late final WebViewController _player;
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _player = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              !request.isMainFrame ||
                  request.url == widget.uri.toString() ||
                  request.url == 'about:blank'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onHttpError: (error) {
            if (error.request?.uri == widget.uri && mounted)
              setState(() {
                _error = 'The video server could not open this player. Return and try again.';
                _loading = false;
              });
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted)
              setState(() {
                _error = 'Could not load the video. Check your connection.';
                _loading = false;
              });
          },
        ),
      )
      ..loadRequest(widget.uri);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.video['title'] as String)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _error != null
              ? Center(child: Text(_error!))
              : Stack(
                  children: [
                    WebViewWidget(controller: _player),
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        Text(
          widget.video['title'] as String,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if ((widget.video['description'] as String?)?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(widget.video['description'] as String),
          ),
      ],
    ),
  );
}
