import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genz_exam_mobile/api/api.dart';
import 'package:genz_exam_mobile/screens/student/video_solutions_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native video catalog filters courses and rejects an unexpected playback origin',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'catalog-session',
      });
      final requests = <RequestOptions>[];
      final client = ApiClient(
        additionalInterceptors: [
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requests.add(request);
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: request.path == '/video-solutions'
                      ? [
                          {
                            'id': 1,
                            'title': 'Linear equations',
                            'course': {'name': 'Maths'},
                            'author': 'Teacher',
                            'locked': false,
                          },
                          {
                            'id': 2,
                            'title': 'Python functions',
                            'course': {'name': 'Python'},
                            'locked': false,
                          },
                        ]
                      : {
                          'embed_src': 'https://unexpected.example/video-solutions/embed/1',
                        },
                ),
              );
            },
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: VideoSolutionsScreen(apiClient: client)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Linear equations'), findsOneWidget);
      expect(find.text('Python functions'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Maths'));
      await tester.pumpAndSettle();
      expect(find.text('Python functions'), findsNothing);
      await tester.enterText(find.byType(TextField), 'not a video');
      await tester.pumpAndSettle();
      expect(find.text('No videos found.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Linear');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Linear equations'));
      await tester.pumpAndSettle();
      expect(requests.last.path, '/video-solutions/1/play');
      expect(
        find.text('The server returned an invalid video source.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
