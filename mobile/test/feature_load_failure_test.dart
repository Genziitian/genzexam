import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genz_exam_mobile/api/api.dart';
import 'package:genz_exam_mobile/screens/student/daily_rewards_screen.dart';
import 'package:genz_exam_mobile/screens/student/uploaded_papers_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const user = UserModel(
    id: 7,
    name: 'Student',
    email: 'student@example.test',
    isAdmin: false,
  );
  late ApiClient client;
  late int status;
  late dynamic data;
  late List<RequestOptions> requests;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'saved-session'});
    status = 403;
    data = '<!DOCTYPE html><html><title>Checking your browser</title></html>';
    requests = [];
    client = ApiClient(
      additionalInterceptors: [
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            if (status == 200) {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: status,
                  data: data,
                ),
              );
            } else {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: request,
                    statusCode: status,
                    data: data,
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  });
  Future<void> mount(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(393, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> uploadedData() => {
    'papers': [
      {'id': 20, 'title': 'Existing revision', 'question_count': 10},
    ],
    'quota': {
      'is_pro': false,
      'limit': 1,
      'remaining': 1,
      'used': 0,
      'pro_limit': 5,
    },
  };
  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets(
    'blocked uploads do not report zero papers or a free quota; retry recovers',
    (tester) async {
      await mount(tester, UploadedPapersScreen(user: user, apiClient: client));
      expect(find.text('Your papers'), findsOneWidget);
      expect(find.text('Your papers (0)'), findsNothing);
      expect(
        find.text(
          'Quiz LAB’s server is blocking this request. Please contact support.',
        ),
        findsOneWidget,
      );
      expect(find.text('Contact support'), findsOneWidget);
      expect(find.textContaining('free upload available'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Upload paper'),
            )
            .onPressed,
        isNull,
      );
      status = 200;
      data = uploadedData();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Your papers (1)'), findsOneWidget);
      expect(find.text('Existing revision'), findsOneWidget);
      expect(find.text('Claim 1 free upload'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    },
  );

  testWidgets('failed upload refresh finishes and retains last loaded papers', (
    tester,
  ) async {
    status = 200;
    data = uploadedData();
    await mount(tester, UploadedPapersScreen(user: user, apiClient: client));
    status = 403;
    data = '<!DOCTYPE html><html>Checking your browser</html>';
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final refreshing = refresh.onRefresh();
    await tester.pumpAndSettle();
    await refreshing;
    expect(find.text('Existing revision'), findsOneWidget);
    expect(find.text('Showing your last loaded data.'), findsOneWidget);
    expect(find.text('Claim 1 free upload'), findsNothing);
    expect(tester.takeException(), isNull);
    await disposeScreen(tester);
  });

  testWidgets(
    'missing rewards route falls back to local snapshot and keeps the native wheel active',
    (tester) async {
      status = 404;
      data = {
        'message': 'The route public/api/student/rewards could not be found.',
      };
      await mount(tester, DailyRewardsScreen(apiClient: client));
      expect(find.text('My Rewards'), findsOneWidget);
      expect(find.textContaining('unavailable right now'), findsNothing);
      expect(
        find.bySemanticsLabel('Reward wheel with ten prizes'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Spin now · Free daily spin'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'incomplete uploads response is an error rather than an empty account',
    (tester) async {
      status = 200;
      data = <String, dynamic>{};
      await mount(tester, UploadedPapersScreen(user: user, apiClient: client));
      expect(find.text('Your papers (0)'), findsNothing);
      expect(
        find.text(
          'Could not confirm your papers and upload allowance. Please try again.',
        ),
        findsOneWidget,
      );
      await disposeScreen(tester);
    },
  );
}
