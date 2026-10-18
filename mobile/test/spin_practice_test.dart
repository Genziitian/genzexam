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
    await tester.pumpWidget(
      MaterialApp(
        home: SpinPracticeScreen(apiClient: client, onOpenMyPapers: () {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectCourse(WidgetTester tester) async {
    final dropdown = find.byType(DropdownButtonFormField<int>);
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
      await tapVisible(tester, 'Weeks 5–8');
      await tapVisible(tester, 'GA');
      await tapVisible(tester, '30 min');
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), ' My revision ');
      await tapVisible(tester, 'Spin the wheel');
      await tester.pump(const Duration(milliseconds: 200));
      expect(generated, hasLength(1));
      expect(generated.single.path, '/student/spin-practice');
      expect(generated.single.headers['Authorization'], 'Bearer test-session');
      expect(generated.single.data, {
        'course_id': 7,
        'week_min': 5,
        'week_max': 8,
        'paper_types': ['ga'],
        'title': 'My revision',
        'time_limit_minutes': 30,
      });
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
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Creating paper…'), findsNothing);
      expect(find.text('6 questions · 30 minutes'), findsOneWidget);
      expect(find.text('Start practice'), findsOneWidget);
      expect(generated, hasLength(1));
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
      await tester.pump(const Duration(seconds: 1));
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
