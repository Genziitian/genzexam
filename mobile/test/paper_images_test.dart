import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genz_exam_mobile/api/api_client.dart';
import 'package:genz_exam_mobile/api/models/quiz_model.dart';
import 'package:genz_exam_mobile/api/offline_paper_store.dart';
import 'package:genz_exam_mobile/api/paper_content.dart';
import 'package:genz_exam_mobile/screens/student/native_paper_room.dart';

const pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('crop URLs resolve to the right host and reject unsafe sources', () {
    expect(
      paperImageUri('/assets/exam-examples/crops/q(1).png'),
      'https://quiz.genziitian.in/assets/exam-examples/crops/q(1).png',
    );
    expect(
      paperImageUri('/storage/crops/option.png'),
      'https://labapi.genziitian.in/storage/crops/option.png',
    );
    for (final source in [
      'javascript:alert(1)',
      'file:///tmp/image.png',
      '//unexpected.example/image.png',
      '/assets/exam-examples/../private.png',
      'https://user:password@example.org/a.png',
      'https://example.org/a.svg',
      'data:image/svg+xml;base64,PHN2Zz4=',
    ]) {
      expect(paperImageUri(source, allowEmbedded: true), isNull);
    }
  });

  test(
    'offline download embeds stem and option crops without parsing code',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final requested = <String>[];
      final imageClient = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requested.add(request.uri.toString());
              expect(request.headers['Authorization'], isNull);
              handler.resolve(
                Response<List<int>>(
                  requestOptions: request,
                  data: base64Decode(pixel),
                  headers: Headers.fromMap({
                    'content-type': ['image/png'],
                  }),
                ),
              );
            },
          ),
        );
      final quiz = QuizDetail.fromJson({
        'id': 987,
        'title': 'Original crops',
        'section': 'practice',
        'questions': [
          {
            'id': 1,
            'type': 'mcq_single',
            'stem':
                'Read the chart.\n![Chart](</assets/exam-examples/q(1).png>)\n'
                '```python\nprint("![not an image](https://ignore.example/code.png)")\n```',
            'options': [
              {'id': 2, 'option_text': '![Option](/storage/option.png)'},
            ],
          },
        ],
      });
      await OfflinePaperStore.cacheQuiz(7, quiz, imageClient: imageClient);
      final saved = await OfflinePaperStore.readQuiz(7, 987);
      expect(saved, isNotNull);
      expect(requested, [
        'https://quiz.genziitian.in/assets/exam-examples/q(1).png',
        'https://labapi.genziitian.in/storage/option.png',
      ]);
      expect(
        saved!.questions.single.stem,
        contains('data:image/png;base64,$pixel'),
      );
      expect(
        saved.questions.single.options.single.optionText,
        contains('data:image/png;base64,$pixel'),
      );
      expect(
        saved.questions.single.stem,
        contains('![not an image](https://ignore.example/code.png)'),
      );
    },
  );

  testWidgets('paper displays prompt and option crops and opens image zoom', (
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
                    ? {'attempt_id': 55}
                    : {
                        'id': 991,
                        'title': 'Cropped paper',
                        'section': 'practice',
                        'questions': [
                          {
                            'id': 1,
                            'type': 'mcq_single',
                            'stem':
                                'Read the original chart.\n![Original chart](<data:image/png;base64,$pixel>)\n'
                                '```pseudocode\nStep 1: Read A\nStep 2: Print A\n```\nChoose the matrix.',
                            'options': [
                              {
                                'id': 2,
                                'option_text':
                                    'Matrix A\n![Matrix option](<data:image/png;base64,$pixel>)',
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
    await tester.pumpWidget(
      MaterialApp(
        home: PaperRoomScreen(
          quizId: 991,
          title: 'Cropped paper',
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
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      ),
      findsNWidgets(2),
    );
    expect(find.text('Step 1: Read A\nStep 2: Print A'), findsOneWidget);
    expect(find.textContaining('![Original chart]'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.semanticLabel == 'Original chart',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Enlarge image').first);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Close image'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
