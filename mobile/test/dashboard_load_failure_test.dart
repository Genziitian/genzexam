import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genz_exam_mobile/api/api.dart';
import 'package:genz_exam_mobile/screens/student/student_main_shell.dart';
import 'package:genz_exam_mobile/state/auth_state.dart';

class _SignedInAuth extends AuthState {
  _SignedInAuth(ApiClient client) : super(apiClient: client);
  @override
  UserModel get user => const UserModel(
    id: 7,
    name: 'Student',
    email: 'student@example.test',
    isAdmin: false,
  );
}

class _ServerErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"message":"Temporary server failure"}',
    500,
    headers: {
      'content-type': ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient client;
  late int status;
  late Object body;
  late int calls;
  late int leaderboardStatus;
  late Map<String, dynamic> leaderboardBody;
  Completer<Map<String, dynamic>>? leaderboardPending;
  final goodDashboard = <String, dynamic>{
    'greeting': {
      'weekday': 'sunday',
      'date': 'Oct 18, 2026',
      'time_of_day': 'evening',
    },
    'streak': {'days': 4, 'history': <int>[]},
    'accuracy': {'value': 75, 'delta': 5, 'history': <int>[]},
    'hours_this_week': {'value': 2, 'delta': 1, 'history': <int>[]},
    'rank': {'current': 12, 'previous': 14, 'moved_up': 2, 'total_ranked': 100},
    'performance': <Map<String, dynamic>>[],
    'community_feed': <Map<String, dynamic>>[],
  };
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-session'});
    ApiClient.connectionUnavailable.value = false;
    calls = 0;
    leaderboardStatus = 200;
    leaderboardPending = null;
    leaderboardBody = {
      'leaderboard': [],
      'me': {'xp': 0, 'level': 1},
    };
    status = 403;
    body = '<!DOCTYPE html><html><title>Checking your browser</title></html>';
    client = ApiClient(
      additionalInterceptors: [
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (!request.path.endsWith('/student/dashboard')) {
              if (request.path.endsWith('/leaderboard') &&
                  leaderboardPending != null) {
                leaderboardPending!.future.then((data) {
                  handler.resolve(
                    Response(requestOptions: request, data: data),
                  );
                });
                return;
              }
              if (request.path.endsWith('/leaderboard') &&
                  leaderboardStatus != 200) {
                handler.reject(
                  DioException(
                    requestOptions: request,
                    type: DioExceptionType.badResponse,
                    response: Response(
                      requestOptions: request,
                      statusCode: leaderboardStatus,
                      data: {'message': 'Rank request failed'},
                    ),
                  ),
                );
                return;
              }
              handler.resolve(
                Response(requestOptions: request, data: leaderboardBody),
              );
              return;
            }
            calls++;
            final response = Response(
              requestOptions: request,
              statusCode: status,
              data: body,
              headers: Headers.fromMap({
                'content-type': [
                  body is String ? 'text/html' : 'application/json',
                ],
              }),
            );
            if (status == 200) {
              handler.resolve(response);
            } else {
              handler.reject(
                DioException(
                  requestOptions: request,
                  response: response,
                  type: DioExceptionType.badResponse,
                ),
              );
            }
          },
        ),
      ],
    );
  });
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _SignedInAuth(client);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(home: StudentMainShell(authState: auth)),
    );
    await flush(tester);
  }

  testWidgets(
    'server block is not an offline dashboard and retry restores progress',
    (tester) async {
      await mount(tester);
      expect(find.text('Could not load dashboard'), findsOneWidget);
      expect(
        find.textContaining('server is blocking this request'),
        findsOneWidget,
      );
      expect(find.text('Contact support'), findsOneWidget);
      expect(find.text('Your progress needs a connection.'), findsNothing);
      expect(find.text('CURRENT STREAK'), findsNothing);
      expect(await client.hasAuthToken(), isTrue);
      status = 200;
      body = goodDashboard;
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await flush(tester);
      expect(calls, 2);
      expect(find.text('Could not load dashboard'), findsNothing);
      expect(find.text('CURRENT STREAK'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets('failed refresh keeps progress and reports saved data', (
    tester,
  ) async {
    status = 200;
    body = goodDashboard;
    await mount(tester);
    status = 403;
    body = '<!DOCTYPE html><html>Checking your browser</html>';
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator).first,
    );
    final refreshing = refresh.onRefresh();
    await flush(tester);
    await refreshing;
    expect(find.text('CURRENT STREAK'), findsOneWidget);
    expect(find.text('Showing your last loaded data.'), findsOneWidget);
    expect(
      find.textContaining('server is blocking this request'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  test('server errors are not lost connectivity', () async {
    client = ApiClient();
    client.dio.httpClientAdapter = _ServerErrorAdapter();
    ApiClient.connectionUnavailable.value = true;
    await expectLater(
      client.get<Map<String, dynamic>>('/student/dashboard'),
      throwsA(isA<ApiException>()),
    );
    expect(ApiClient.connectionUnavailable.value, isFalse);
    expect(await client.hasAuthToken(), isTrue);
  });

  testWidgets(
    'Home rank keeps the server dashboard rank if leaderboard fails',
    (tester) async {
      status = 200;
      body = goodDashboard;
      leaderboardStatus = 403;
      await mount(tester);
      expect(find.text('#12'), findsOneWidget);
      expect(find.text('unranked'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'Home rank is visible while the separate rank request is still loading',
    (tester) async {
      status = 200;
      body = goodDashboard;
      leaderboardPending = Completer<Map<String, dynamic>>();
      await mount(tester);
      expect(find.text('#12'), findsOneWidget);
      leaderboardPending!.complete({...leaderboardBody, 'my_rank': 3});
      await flush(tester);
      expect(find.text('#3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'Home rank reports unavailable instead of inventing an unranked user',
    (tester) async {
      status = 200;
      body = {
        ...goodDashboard,
        'rank': {'current': null, 'total_ranked': 100},
      };
      leaderboardStatus = 403;
      await mount(tester);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('unranked'), findsNothing);
      expect(find.text('New'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'Home rank uses the leaderboard result including a confirmed unranked result',
    (tester) async {
      status = 200;
      body = goodDashboard;
      leaderboardBody['my_rank'] = 3;
      await mount(tester);
      expect(find.text('#3'), findsOneWidget);
      expect(find.text('#12'), findsNothing);
      leaderboardBody.remove('my_rank');
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator).first,
      );
      final refreshing = refresh.onRefresh();
      await flush(tester);
      await refreshing;
      expect(find.text('unranked'), findsOneWidget);
      expect(find.text('#12'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
