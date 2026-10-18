import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genz_exam_mobile/api/api.dart';
import 'package:genz_exam_mobile/api/rewards_service.dart';
import 'package:genz_exam_mobile/screens/student/daily_rewards_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient client;
  late List<RequestOptions> writes;
  late Completer<Map<String, dynamic>> spin;
  late List<Map<String, dynamic>> rewards;
  late int remaining;
  late bool revealed;
  late bool loadUnavailable;
  late int uploadOpens, testOpens;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'native-session'});
    writes = [];
    rewards = [];
    remaining = 1;
    revealed = false;
    loadUnavailable = false;
    uploadOpens = 0;
    testOpens = 0;
    spin = Completer<Map<String, dynamic>>();
    client = ApiClient(
      additionalInterceptors: [
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            expect(request.headers['Authorization'], 'Bearer native-session');
            if (request.method == 'GET') {
              if (loadUnavailable) {
                handler.reject(
                  DioException(
                    requestOptions: request,
                    type: DioExceptionType.badResponse,
                    response: Response(
                      requestOptions: request,
                      statusCode: 404,
                      data: {'message': 'The route could not be found.'},
                    ),
                  ),
                );
                return;
              }
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {
                    'quota': {'remaining': remaining},
                    'rewards': rewards,
                  },
                ),
              );
              return;
            }
            writes.add(request);
            if (request.path.endsWith('/spin')) {
              final data = await spin.future;
              if (data['error'] != null) {
                handler.reject(
                  DioException(
                    requestOptions: request,
                    type: DioExceptionType.badResponse,
                    response: Response(
                      requestOptions: request,
                      statusCode: 503,
                      data: data,
                    ),
                  ),
                );
              } else {
                remaining = 0;
                rewards = [Map<String, dynamic>.from(data['reward'] as Map)];
                handler.resolve(Response(requestOptions: request, data: data));
              }
            } else if (request.path.endsWith('/scratch')) {
              revealed = true;
              rewards.first['is_scratched'] = true;
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {'success': true, 'id': request.data['id']},
                ),
              );
            } else if (request.path.endsWith('/claim-pro')) {
              rewards.first['is_claimed'] = true;
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {'success': true, 'message': 'Pro activated by server'},
                ),
              );
            }
          },
        ),
      ],
    );
  });

  Future<void> mount(WidgetTester tester) async {
    spin = Completer<Map<String, dynamic>>();
    await tester.binding.setSurfaceSize(const Size(393, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: DailyRewardsScreen(
            apiClient: client,
            onOpenUploadPaper: () => uploadOpens++,
            onOpenTestYourself: () => testOpens++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'native spin uses one server write, reveals saved reward and claims Pro',
    (tester) async {
      await mount(tester);
      await tester.ensureVisible(find.text('Spin now · Free daily spin'));
      await tester.tap(find.text('Spin now · Free daily spin'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(writes, hasLength(1));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Spinning…'),
            )
            .onPressed,
        isNull,
      );
      spin.complete({
        'segment': 1,
        'quota': {'remaining': 0},
        'prize': {'title': '30 Days Free Pro'},
        'reward': {
          'id': 'won-pro',
          'type': 'free_pro',
          'title': '30 Days Free Pro',
          'is_scratched': false,
          'is_claimed': false,
        },
      });
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('30 Days Free Pro'), findsOneWidget);
      await tester.tap(find.text('My Rewards'));
      await tester.pumpAndSettle();
      expect(find.text('Your reward is ready'), findsOneWidget);
      await tester.tap(find.text('Reveal reward'));
      await tester.pumpAndSettle();
      expect(revealed, isTrue);
      expect(writes.last.data, {'id': 'won-pro'});
      await tester.tap(find.text('Activate Pro'));
      await tester.pumpAndSettle();
      expect(writes.last.path, '/student/rewards/claim-pro');
      expect(writes.last.data, {'id': 'won-pro'});
      expect(find.text('Applied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing rewards API disables spinning until a successful retry',
    (tester) async {
      loadUnavailable = true;
      await mount(tester);
      expect(find.textContaining('unavailable on the server'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Rewards unavailable · Try again',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(writes, isEmpty);
      loadUnavailable = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Spin now · Free daily spin'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('reward rules expand without a ListTile material assertion', (
    tester,
  ) async {
    await mount(tester);
    await tester.ensureVisible(find.text('Rules and Conditions'));
    await tester.tap(find.text('Rules and Conditions'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Daily Free Spin Allowance', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final coupon in [
    ('coupon_pct', '5% OFF (Upto ₹50)', 'GENZ5-DEMO', 'Up to ₹50'),
    ('coupon_pct', '25% OFF Coupon', 'GENZ25-DEMO', 'Up to ₹100'),
    ('coupon_flat', '₹50 OFF Coupon', 'GENZ50-DEMO', '₹350'),
  ]) {
    testWidgets(
      'coupon ${coupon.$2} has matching instructions beside one copy action',
      (tester) async {
        rewards = [
          {
            'id': 'coupon',
            'type': coupon.$1,
            'title': coupon.$2,
            'code': coupon.$3,
            'is_scratched': true,
            'expires_at': DateTime.now()
                .add(const Duration(days: 7))
                .toIso8601String(),
          },
        ];
        final copied = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData')
              copied.add((call.arguments as Map)['text'] as String);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await mount(tester);
        await tester.tap(find.text('My Rewards (1)'));
        await tester.pumpAndSettle();
        expect(find.text('Copy'), findsNothing);
        expect(find.text('Copy code'), findsOneWidget);
        expect(
          tester.getCenter(find.text('Instructions')).dy,
          closeTo(tester.getCenter(find.text('Copy code')).dy, 1),
        );
        await tester.tap(find.text('Instructions'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Genziitian.in/courses', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining(coupon.$4, findRichText: true),
          findsOneWidget,
        );
        expect(find.text('Visit courses'), findsOneWidget);
        expect(writes, isEmpty);
        await tester.tap(find.text('Copy code'));
        await tester.pumpAndSettle();
        expect(copied, [coupon.$3]);
        expect(writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final bonus in [
    ('free_paper_upload', 'Free 1 Paper Upload', 'Upload paper now', 9),
    ('free_test', 'Free 1 Test Yourself', 'Test yourself now', 8),
  ]) {
    testWidgets(
      '${bonus.$1} opens its destination from the win message and saved reward',
      (tester) async {
        final reward = <String, dynamic>{
          'id': 'bonus',
          'type': bonus.$1,
          'title': bonus.$2,
          'is_scratched': true,
          'is_claimed': true,
        };
        await mount(tester);
        await tester.ensureVisible(find.text('Spin now · Free daily spin'));
        await tester.tap(find.text('Spin now · Free daily spin'));
        await tester.pump();
        spin.complete({
          'segment': bonus.$4,
          'quota': {'remaining': 0},
          'prize': {'title': bonus.$2},
          'reward': reward,
        });
        await tester.pumpAndSettle();
        expect(find.textContaining('view your code'), findsNothing);
        expect(find.text(bonus.$3), findsOneWidget);
        expect(find.text('My Rewards'), findsOneWidget);
        await tester.tap(find.text(bonus.$3));
        await tester.pumpAndSettle();
        expect(bonus.$1 == 'free_paper_upload' ? uploadOpens : testOpens, 1);
        await tester.tap(find.text('My Rewards (1)'));
        await tester.pumpAndSettle();
        expect(find.text('Applied'), findsNothing);
        await tester.tap(find.text('Instructions'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            'No coupon code or payment needed',
            findRichText: true,
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(bonus.$3));
        await tester.pumpAndSettle();
        expect(bonus.$1 == 'free_paper_upload' ? uploadOpens : testOpens, 2);
        expect(writes, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'missing server endpoints never generate rewards or claim Pro locally',
    () async {
      final requests = <RequestOptions>[];
      final unavailableClient = ApiClient(
        additionalInterceptors: [
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requests.add(request);
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: request,
                    statusCode: 404,
                    data: {'message': 'The route could not be found.'},
                  ),
                ),
              );
            },
          ),
        ],
      );
      final service = RewardsService(unavailableClient);
      await expectLater(service.load(), throwsA(isA<ApiException>()));
      await expectLater(service.spin(), throwsA(isA<ApiException>()));
      await expectLater(
        service.reveal('server-reward'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        service.claimPro('server-reward'),
        throwsA(isA<ApiException>()),
      );
      expect(requests.map((r) => r.path), [
        '/student/rewards',
        '/student/rewards/spin',
        '/student/rewards/scratch',
        '/student/rewards/claim-pro',
      ]);
    },
  );

  testWidgets(
    'failed spin cannot be repeated until rewards have been refreshed',
    (tester) async {
      await mount(tester);
      await tester.ensureVisible(find.text('Spin now · Free daily spin'));
      await tester.tap(find.text('Spin now · Free daily spin'));
      await tester.pump(const Duration(milliseconds: 200));
      spin.complete({'error': 'Temporary server failure'});
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Rewards unavailable · Try again',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('Temporary server failure'), findsOneWidget);
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Spin now · Free daily spin'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('expired reward never exposes its coupon code or an action', (
    tester,
  ) async {
    rewards = [
      {
        'id': 'expired',
        'type': 'coupon_flat',
        'title': 'Old coupon',
        'code': 'DO-NOT-SHOW',
        'is_scratched': true,
        'expires_at': '2020-01-01T00:00:00Z',
      },
    ];
    await mount(tester);
    await tester.tap(find.text('My Rewards (1)'));
    await tester.pumpAndSettle();
    expect(find.text('DO-NOT-SHOW'), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Expired'))
          .onPressed,
      isNull,
    );
  });

  test(
    'HTML hosting challenge remains distinct from account authorization',
    () {
      final request = RequestOptions(path: '/courses');
      final error = ApiException.fromDioException(
        DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: request,
            statusCode: 403,
            data: '<!DOCTYPE html><html><title>Checking your browser before accessing. Just a moment...</title></html>',
          ),
        ),
      );
      expect(error.isSecurityChallenge, isTrue);
      expect(error.isUnauthorized, isFalse);
      expect(error.message, contains('server is blocking'));
      final denied = ApiException.fromDioException(
        DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: request,
            statusCode: 403,
            data: {'error': 'This video requires Pro.'},
          ),
        ),
      );
      expect(denied.isSecurityChallenge, isFalse);
      expect(denied.message, 'This video requires Pro.');
    },
  );
}
