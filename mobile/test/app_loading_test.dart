import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genz_exam_mobile/state/app_activity.dart';
import 'package:genz_exam_mobile/widgets/app_loading_layer.dart';

void main() {
  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => AppLoadingLayer(child: child!),
      home: const Scaffold(body: Text('Current screen')),
    ),
  );

  testWidgets('overlapping work stays visible until the last task ends', (
    tester,
  ) async {
    await mount(tester);
    final first = AppActivity.begin('Saving profile…');
    final second = AppActivity.begin('Uploading paper…');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.text('Uploading paper…'), findsOneWidget);
    expect(find.byType(ModalBarrier), findsWidgets);
    second();
    await tester.pump();
    expect(find.text('Saving profile…'), findsOneWidget);
    first();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Current screen'), findsOneWidget);
  });

  testWidgets('errors release the loader and still reach the caller', (
    tester,
  ) async {
    await mount(tester);
    final response = Completer<void>();
    final work = AppActivity.run('Importing…', () => response.future);
    final expectation = expectLater(work, throwsStateError);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.text('Importing…'), findsOneWidget);
    response.completeError(StateError('Import rejected'));
    await expectation;
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'fast requests do not flash a modal; autosave stays nonblocking',
    (tester) async {
      await mount(tester);
      final quick = AppActivity.begin('Saving…');
      quick();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Saving…'), findsNothing);
      final autosave = AppActivity.request(
        '/exam-platform/exams/1/answers',
        'PATCH',
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(AppActivity.current.value?.blocking, false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      autosave();
      await tester.pump();
    },
  );

  testWidgets('long waits can be minimized without reporting completion', (
    tester,
  ) async {
    await mount(tester);
    final finish = AppActivity.begin('Preparing paper…');
    await tester.pump(const Duration(seconds: 13));
    await tester.pump();
    expect(find.textContaining('taking longer'), findsOneWidget);
    await tester.tap(find.text('Keep browsing'));
    await tester.pump();
    expect(AppActivity.current.value?.blocking, false);
    expect(find.textContaining('still working'), findsOneWidget);
    finish();
    finish();
    await tester.pump();
    expect(AppActivity.current.value, isNull);
  });
}
