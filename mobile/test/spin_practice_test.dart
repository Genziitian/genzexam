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
  late List<RequestOptions> quotaRequests;
  late Map<String, dynamic> quotaResponse;
  int? quotaFailureStatus;
  int? courseFailureStatus;
  Completer<Map<String, dynamic>>? quotaPending;
  late Completer<Map<String, dynamic>> response;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-session'});
    generated = [];
    quotaRequests = [];
    quotaFailureStatus = null;
    courseFailureStatus = null;
    quotaPending = null;
    quotaResponse = {
      'quota': {'is_pro': false, 'limit': 1, 'used': 0, 'remaining': 1},
    };
    response = Completer<Map<String, dynamic>>();
    client = ApiClient(
      additionalInterceptors: [
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            if (request.path == '/courses') {
              if (courseFailureStatus != null) {
                handler.reject(
                  DioException(
                    requestOptions: request,
                    type: DioExceptionType.badResponse,
                    response: Response(
                      requestOptions: request,
                      statusCode: courseFailureStatus,
                      data: {'error': 'Courses are temporarily unavailable.'},
                    ),
                  ),
                );
                return;
              }
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: [
                    {'id': 7, 'name': 'Maths 1', 'slug': 'maths-1'},
                  ],
                ),
              );
            } else if (request.path == '/student/spin-practice/quota') {
              quotaRequests.add(request);
              if (quotaFailureStatus != null) {
                handler.reject(
                  DioException(
                    requestOptions: request,
                    type: DioExceptionType.badResponse,
                    response: Response(
                      requestOptions: request,
                      statusCode: quotaFailureStatus,
                      data: {'error': 'Spins are temporarily unavailable.'},
                    ),
                  ),
                );
                return;
              }
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: quotaPending != null
                      ? await quotaPending!.future
                      : quotaResponse,
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
                      statusCode: result['status_code'] as int? ?? 422,
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
    final finder = find.textContaining(label);
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

  testWidgets('quota failure can retry without losing course or paper name', (
    tester,
  ) async {
    quotaFailureStatus = 403;
    await mount(tester);
    expect(find.text('Spins are temporarily unavailable.'), findsOneWidget);
    expect(find.text('Retry spin allowance'), findsOneWidget);
    expect(find.text('Unlock 7 spins/day with Pro'), findsNothing);
    await selectCourse(tester);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'My saved selection');
    quotaFailureStatus = null;
    await tester.tap(find.text('Retry spin allowance'));
    await tester.pumpAndSettle();
    expect(quotaRequests, hasLength(2));
    expect(find.text('Spins are temporarily unavailable.'), findsNothing);
    expect(find.text('Spin the wheel · 1 free spin left'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'My saved selection',
    );
    await tester.ensureVisible(find.byKey(const Key('spin-course')));
    expect(find.text('Maths 1'), findsOneWidget);
    expect(generated, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('course error retry also reloads the failed spin allowance', (
    tester,
  ) async {
    courseFailureStatus = 403;
    quotaFailureStatus = 403;
    await mount(tester);
    expect(find.text('Courses are temporarily unavailable.'), findsOneWidget);
    courseFailureStatus = null;
    quotaFailureStatus = null;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(quotaRequests, hasLength(2));
    expect(find.text('Spin the wheel · 1 free spin left'), findsOneWidget);
    expect(find.text('Test yourself'), findsOneWidget);
    expect(generated, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('spin stays disabled until the server confirms its allowance', (
    tester,
  ) async {
    quotaPending = Completer<Map<String, dynamic>>();
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: SpinPracticeScreen(apiClient: client, onOpenMyPapers: () {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final button = find.widgetWithText(
      FilledButton,
      'Checking available spins…',
    );
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(generated, isEmpty);
    quotaPending!.complete(quotaResponse);
    await tester.pumpAndSettle();
    expect(find.text('Spin the wheel · 1 free spin left'), findsOneWidget);
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
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const Key('spin-background-dim')),
            )
            .opacity,
        .18,
      );
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
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('Creating paper…'), findsNothing);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Try now'), findsOneWidget);
      expect(find.text('Spin again'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(generated, hasLength(1));
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const Key('spin-background-dim')),
            )
            .opacity,
        1,
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Try now'), findsNothing);
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
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
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
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('No questions found for these weeks.'), findsOneWidget);
      expect(find.text('Start practice'), findsNothing);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Spin the wheel · 1 free spin left'),
      );
      expect(button.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'daily limit updates from the server without replaying the spin',
    (tester) async {
      await mount(tester);
      await selectCourse(tester);
      await tapVisible(tester, 'Spin the wheel');
      await tester.pump(const Duration(milliseconds: 200));
      response.complete({
        'error': 'You have used your free spin today.',
        'status_code': 429,
        'quota': {'is_pro': false, 'limit': 1, 'used': 1, 'remaining': 0},
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Creating paper…'), findsNothing);
      expect(find.text('You have used your free spin today.'), findsOneWidget);
      expect(find.text('Unlock 7 spins/day with Pro'), findsOneWidget);
      expect(generated, hasLength(1));
      expect(quotaRequests, hasLength(1));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'paper modal can spin again without duplicate requests or disposal errors',
    (tester) async {
      await mount(tester);
      await selectCourse(tester);
      await tapVisible(tester, 'Spin the wheel');
      await tester.pump(const Duration(milliseconds: 200));
      response.complete({
        'id': 101,
        'title': 'Private revision',
        'question_count': 8,
        'time_limit_minutes': 20,
        'quota': {'remaining': 6},
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      response = Completer<Map<String, dynamic>>();
      await tester.tap(find.text('Spin again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(generated, hasLength(2));
      expect(find.text('Try now'), findsNothing);
      response.complete({
        'id': 102,
        'title': 'Second private revision',
        'question_count': 10,
        'time_limit_minutes': 20,
        'quota': {'remaining': 0},
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('Second private revision'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Spin again'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock 7 spins/day with Pro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('rejects incomplete responses instead of inventing a paper', () {
    expect(
      () => GeneratedPracticePaper.fromJson({'id': 99}),
      throwsA(isA<ApiException>()),
    );
  });

  test(
    'quota service surfaces server rejection instead of hiding it',
    () async {
      quotaFailureStatus = 403;
      await expectLater(
        SpinPracticeService(client: client).getQuota(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            403,
          ),
        ),
      );
    },
  );

  test('quota service rejects a missing or incomplete allowance', () async {
    quotaResponse = {};
    await expectLater(
      SpinPracticeService(client: client).getQuota(),
      throwsA(isA<ApiException>()),
    );
    quotaResponse = {
      'quota': {'is_pro': false, 'limit': 1},
    };
    await expectLater(
      SpinPracticeService(client: client).getQuota(),
      throwsA(isA<ApiException>()),
    );
  });
}
