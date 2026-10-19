import 'api_client.dart';

// Code and math consume their contents before Markdown images are considered.
final paperContentPattern = RegExp(
  r'(`{3,})([^\n`]*)\n([\s\S]*?)\1|`[^`\n]*`|\$\$[\s\S]*?\$\$|\\\[[\s\S]*?\\\]|\\\([\s\S]*?\\\)|\$[^$\n]+\$|!\[([^\]\n]*)\]\((?:<([^<>\r\n]+)>|([^\s)]+))\)',
);

String? paperImageUri(
  String source, {
  String apiBaseUrl = ApiClient.defaultBaseUrl,
  bool allowEmbedded = false,
}) {
  var value = source.trim();
  if (allowEmbedded &&
      RegExp(r'^data:image/(png|jpeg|webp|gif);base64,[A-Za-z0-9+/=]+$')
          .hasMatch(value)) {
    return value;
  }
  if (value == 'oct2022_q1_figure1.png' ||
      value.endsWith('/oct2022_q1_figure1.png')) {
    value =
        '/assets/exam-examples/question-crops/mathematics-1/quiz1/oct2022_q1_figure1.png';
  }
  if (value.startsWith('assets/')) {
    value = '/$value';
  } else if (value.startsWith('question-crops/')) {
    value = '/assets/exam-examples/$value';
  } else if (value.startsWith('/question-crops/')) {
    value = '/assets/exam-examples$value';
  }
  try {
    if (RegExp(r'(^|[/\\])\.\.?([/\\?#]|$)')
        .hasMatch(Uri.decodeComponent(value)))
      return null;
  } on FormatException {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.userInfo.isNotEmpty || value.contains('\\'))
    return null;
  if (uri.pathSegments.any((part) => part == '..' || part == '.') ||
      uri.path.toLowerCase().endsWith('.svg')) {
    return null;
  }
  if (uri.scheme == 'https' && uri.host.isNotEmpty) return uri.toString();
  if (uri.hasScheme || uri.hasAuthority) return null;
  if (value.startsWith('/assets/exam-examples/')) {
    return Uri.https(
      'quiz.genziitian.in',
      uri.path,
    ).replace(query: uri.query.isEmpty ? null : uri.query).toString();
  }
  if (value.startsWith('/storage/') || value.startsWith('/uploads/')) {
    return Uri.parse(apiBaseUrl).resolve(value).toString();
  }
  return null;
}
