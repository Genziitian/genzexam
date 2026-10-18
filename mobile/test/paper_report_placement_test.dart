import 'dart:io';

import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genz_exam_mobile/api/api_client.dart';
import 'package:genz_exam_mobile/screens/student/native_paper_room.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use the SDK's real phone font for geometry checks, rather than Ahem's
    // square test glyphs, which have very different text widths.
    var directory = File(Platform.resolvedExecutable).parent;
    File? fontFile;
    for (var i = 0; i < 8; i++) {
      for (final suffix in [
        'material_fonts/Roboto-Regular.ttf',
        'artifacts/material_fonts/Roboto-Regular.ttf',
      ]) {
        final candidate = File('${directory.path}/$suffix');
        if (candidate.existsSync()) fontFile = candidate;
      }
      if (fontFile != null) break;
      directory = directory.parent;
    }
    if (fontFile == null) throw StateError('Flutter SDK Roboto font not found');
    await (FontLoader('Roboto')..addFont(
          Future.value(ByteData.sublistView(fontFile.readAsBytesSync())),
        ))
        .load();
  });
  for (final width in [320.0, 393.0]) {
    testWidgets('report stays between timer and submit at width $width', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      final client = ApiClient(
        additionalInterceptors: [
          InterceptorsWrapper(
            onRequest: (request, handler) {
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: request.method == 'POST'
                      ? {'attempt_id': 101}
                      : {
                          'id': 99,
                          'title': 'Practice paper',
                          'section': 'practice',
                          'time_limit_minutes': 20,
                          'questions': [
                            {
                              'id': 1,
                              'type': 'mcq_single',
                              'stem': 'Select the correct answer.',
                              'marks': 1,
                              'options': [
                                {
                                  'id': 1,
                                  'option_text': 'Answer',
                                  'position': 1,
                                },
                              ],
                            },
                          ],
                        },
                ),
              );
            },
          ),
        ],
      );
      await tester.binding.setSurfaceSize(Size(width, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PaperRoomScreen(
            quizId: 99,
            title: 'Practice paper',
            apiClient: client,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.scrollUntilVisible(
        find.text('Start paper'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Start paper'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final report = find.byTooltip('Report question');
      expect(report, findsOneWidget);
      final reportRect = tester.getRect(report);
      final submitRect = tester.getRect(
        find.widgetWithText(FilledButton, 'Submit & Exit'),
      );
      final clockRect = tester.getRect(
        find.textContaining(RegExp(r'^\d\d:\d\d$')),
      );
      expect(reportRect.left, greaterThan(clockRect.right));
      expect(reportRect.right, lessThan(submitRect.left));
      expect((reportRect.center.dy - submitRect.center.dy).abs(), lessThan(3));
      expect(tester.takeException(), isNull);
      await tester.tap(report);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Report question 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
