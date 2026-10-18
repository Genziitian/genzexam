import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genz_exam_mobile/api/api.dart';
import 'package:genz_exam_mobile/screens/student/daily_rewards_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient client;
  late List<RequestOptions> writes;
  late Completer<Map<String, dynamic>> spin;
  late List<Map<String, dynamic>> rewards;
  late int remaining;
  late bool revealed;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'native-session'});
    writes = [];
    rewards = [];
    remaining = 1;
    revealed = false;
    spin = Completer<Map<String, dynamic>>();
    client = ApiClient(
      additionalInterceptors: [
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            expect(request.headers['Authorization'], 'Bearer native-session');
            if (request.method == 'GET') {
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
          child: DailyRewardsScreen(apiClient: client),
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
              find.widgetWithText(FilledButton, 'Spin now · Free daily spin'),
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
