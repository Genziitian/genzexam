import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genz_exam_mobile/api/api.dart';
import 'package:genz_exam_mobile/api/spin_practice_service.dart';
import 'package:genz_exam_mobile/screens/student/spin_practice_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient client;
  late List<RequestOptions> generated;
  late Completer<Map<String, dynamic>> response;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-session'});
    generated = [];
    response = Completer<Map<String, dynamic>>();
    client = ApiClient(
      additionalInterceptors: [
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            if (request.path == '/courses') {
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: [
                    {'id': 7, 'name': 'Maths 1', 'slug': 'maths-1'},
                  ],
                ),
              );
            } else {
              generated.add(request);
              final result = await response.future;
              if (result['error'] != null) {
                handler.reject(
                  DioException(
                    requestOptions: request,
                    type: DioExceptionType.badResponse,
                    response: Response(
                      requestOptions: request,
                      statusCode: 422,
                      data: result,
                    ),
                  ),
                );
              } else {
                handler.resolve(
                  Response(
                    requestOptions: request,
                    statusCode: 201,
                    data: result,
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  });

  Future<void> mount(WidgetTester tester) async {
    response = Completer<Map<String, dynamic>>();
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: SpinPracticeScreen(apiClient: client, onOpenMyPapers: () {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectCourse(WidgetTester tester) async {
    final dropdown = find.byKey(const Key('spin-course'));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maths 1').last);
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('requires a course without sending a generation request', (
    tester,
  ) async {
    await mount(tester);
    await tapVisible(tester, 'Spin the wheel');
    expect(find.text('Choose a course first.'), findsOneWidget);
    expect(generated, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'submits selected options once and shows only the server result',
    (tester) async {
      await mount(tester);
      await selectCourse(tester);
      final slider = find.byType(RangeSlider);
      await tester.ensureVisible(slider);
      final sliderRect = tester.getRect(slider);
      await tester.dragFrom(
        Offset(sliderRect.left + 24, sliderRect.center.dy),
        Offset(sliderRect.width * 0.3, 0),
      );
      await tester.pumpAndSettle();
      final weeks = tester.widget<RangeSlider>(slider).values;
      await tapVisible(tester, 'All types');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'PA'));
      await tester.pump();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'GA'));
      await tester.pump();
      await tester.tap(find.text('Apply selection'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), ' My revision ');
      await tapVisible(tester, 'Spin the wheel');
      await tester.pump(const Duration(milliseconds: 200));
      expect(generated, hasLength(1));
      expect(generated.single.path, '/student/spin-practice');
      expect(generated.single.headers['Authorization'], 'Bearer test-session');
      expect(generated.single.data, {
        'course_id': 7,
        'week_min': weeks.start.round(),
        'week_max': weeks.end.round(),
        'paper_types': ['pa', 'ga'],
        'title': 'My revision',
      });
      expect(generated.single.data.containsKey('time_limit_minutes'), isFalse);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Creating paper…'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Start practice'), findsNothing);
      response.complete({
        'id': 99,
        'title': 'My revision',
        'question_count': 6,
        'time_limit_minutes': 30,
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Creating paper…'), findsNothing);
      expect(
        find.text('6 questions · Choose your time when you open it'),
        findsOneWidget,
      );
      expect(find.text('Start practice'), findsOneWidget);
      expect(generated, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'All types replaces individual selections and time stays out of setup',
    (tester) async {
      await mount(tester);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Time limit'), findsNothing);
      expect(find.text('All weeks'), findsNothing);
      await selectCourse(tester);
      await tapVisible(tester, 'All types');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'PA'));
      await tester.pump();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'GA'));
      await tester.pump();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'All types'));
      await tester.pump();
      await tester.tap(find.text('Apply selection'));
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Spin the wheel');
      await tester.pump(const Duration(milliseconds: 200));
      expect(generated.single.data['paper_types'], ['all']);
      expect(generated.single.data.containsKey('time_limit_minutes'), isFalse);
      response.complete({
        'id': 100,
        'title': 'All types practice',
        'question_count': 10,
        'time_limit_minutes': 20,
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty question pool shows the server error and allows another spin',
    (tester) async {
      await mount(tester);
      await selectCourse(tester);
      await tapVisible(tester, 'Spin the wheel');
      await tester.pump(const Duration(milliseconds: 200));
      response.complete({'error': 'No questions found for these weeks.'});
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('No questions found for these weeks.'), findsOneWidget);
      expect(find.text('Start practice'), findsNothing);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Spin the wheel'),
      );
      expect(button.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  test('rejects incomplete responses instead of inventing a paper', () {
    expect(
      () => GeneratedPracticePaper.fromJson({'id': 99}),
      throwsA(isA<ApiException>()),
    );
  });
}
