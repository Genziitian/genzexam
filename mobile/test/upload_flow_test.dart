import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'
    show FlutterSecureStorage;
import 'package:flutter_test/flutter_test.dart';
import 'package:genz_exam_mobile/api/api.dart';
import 'package:genz_exam_mobile/api/uploaded_papers_service.dart';
import 'package:genz_exam_mobile/screens/student/uploaded_papers_screen.dart';

final class _SelectedFile extends PlatformFile {
  _SelectedFile({
    this.name = 'revision.json',
    this.size,
    this.unreadable = false,
    List<int>? bytes,
  }) : bytes = Uint8List.fromList(
         bytes ?? utf8.encode('[{"stem":"Question?"}]'),
       );

  @override
  final String name;
  final int? size;
  final bool unreadable;
  final Uint8List bytes;

  @override
  Uri get uri => Uri.parse('content://documents/selected-paper');
  @override
  Never get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => size;
  @override
  Future<int?> length() async => size;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() async* {
    if (unreadable) throw StateError('Native file is no longer readable.');
    yield bytes;
  }
}

class _NativePicker extends FilePickerPlatform {
  int calls = 0;
  Future<List<PlatformFile>> Function() result = () async => [];

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) {
    calls++;
    expect(type, FileType.custom);
    expect(allowedExtensions, ['pdf', 'json']);
    return result();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const user = UserModel(
    id: 7,
    name: 'Student',
    email: 'student@example.test',
    isAdmin: false,
  );
  final originalPicker = FilePickerPlatform.instance;
  late _NativePicker picker;
  late ApiClient client;
  late UploadedPapersService service;
  late List<RequestOptions> writes;
  late Map<String, dynamic> listData;
  late dynamic uploadData;
  late int uploadStatus;
  late int reads;
  Completer<void>? uploadWait;

  Map<String, dynamic> quota({int remaining = 1}) => {
    'is_pro': false,
    'limit': 1,
    'pro_limit': 5,
    'used': 1 - remaining,
    'remaining': remaining,
    'window_days': 7,
    'resets_at': null,
  };
  Map<String, dynamic> existing() => {
    'id': 20,
    'title': 'Existing revision',
    'question_count': 10,
  };
  Map<String, dynamic> created() => {
    'id': 21,
    'title': 'Converted revision',
    'question_count': 3,
  };

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'upload-session'});
    picker = _NativePicker();
    FilePickerPlatform.instance = picker;
    writes = [];
    reads = 0;
    uploadWait = null;
    listData = {
      'papers': [existing()],
      'quota': quota(),
    };
    uploadData = created();
    uploadStatus = 201;
    client = ApiClient(
      additionalInterceptors: [
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            expect(request.path, '/student/uploaded-papers');
            expect(request.headers['Authorization'], 'Bearer upload-session');
            if (request.method == 'GET') {
              reads++;
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: listData,
                ),
              );
              return;
            }
            writes.add(request);
            if (uploadWait != null) await uploadWait!.future;
            if (uploadStatus >= 400) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: request,
                    statusCode: uploadStatus,
                    data: uploadData,
                  ),
                ),
              );
              return;
            }
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: uploadStatus,
                data: uploadData,
              ),
            );
          },
        ),
      ],
    );
    service = UploadedPapersService(client: client);
  });
  tearDown(() => FilePickerPlatform.instance = originalPicker);

  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: UploadedPapersScreen(user: user, apiClient: client),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  test(
    'uploads picker bytes without a local path using one multipart request',
    () async {
      final file = _SelectedFile();
      expect(file.path, isNull);
      final paper = await service.upload(file);
      expect(paper.id, 21);
      expect(paper.questionCount, 3);
      expect(writes, hasLength(1));
      final request = writes.single;
      expect(request.contentType, 'multipart/form-data');
      final part = (request.data as FormData).files.single;
      expect(part.key, 'paper');
      expect(part.value.filename, 'revision.json');
      final bytes = await part.value.finalize().fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
      expect(bytes, file.bytes);
    },
  );

  test(
    'invalid, empty, oversized and unreadable files never reach the server',
    () async {
      for (final file in [
        _SelectedFile(name: 'revision.exe'),
        _SelectedFile(bytes: []),
        _SelectedFile(size: 10 * 1024 * 1024 + 1),
        _SelectedFile(bytes: Uint8List(10 * 1024 * 1024 + 1)),
        _SelectedFile(unreadable: true),
      ]) {
        await expectLater(service.upload(file), throwsA(isA<ApiException>()));
      }
      expect(writes, isEmpty);
    },
  );

  test(
    'malformed rows and incomplete quota never appear as an empty account',
    () async {
      for (final data in [
        {
          'papers': [null],
          'quota': quota(),
        },
        {
          'papers': [
            {'id': 20},
          ],
          'quota': quota(),
        },
        {'papers': [], 'quota': <String, dynamic>{}},
        {
          'papers': [],
          'quota': {...quota(), 'remaining': 2},
        },
      ]) {
        listData = data;
        await expectLater(service.list(), throwsA(isA<ApiException>()));
      }
    },
  );

  test(
    'a successful HTTP response must contain a real converted paper',
    () async {
      for (final data in [
        <String, dynamic>{},
        '<html>Server verification</html>',
        {...created(), 'id': 0},
        {...created(), 'question_count': 0},
      ]) {
        uploadData = data;
        await expectLater(
          service.upload(_SelectedFile()),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );

  testWidgets('picker is single flight and cancel restores the screen', (
    tester,
  ) async {
    final pending = Completer<List<PlatformFile>>();
    picker.result = () => pending.future;
    await mount(tester);
    final upload = find.widgetWithText(FilledButton, 'Claim 1 free upload');
    final start = tester.widget<FilledButton>(upload).onPressed!;
    start();
    start();
    await tester.pump();
    expect(picker.calls, 1);
    expect(tester.widget<FilledButton>(upload).onPressed, isNull);
    expect(writes, isEmpty);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(upload).onPressed, isNotNull);
    expect(find.text('Upload rules'), findsOneWidget);
    expect(find.text('Existing revision'), findsOneWidget);
    expect(reads, 1);
    expect(tester.takeException(), isNull);
    await disposeScreen(tester);
  });

  testWidgets(
    'native picker error restores rules and allows another selection',
    (tester) async {
      picker.result = () async =>
          throw PlatformException(code: 'picker_failed');
      await mount(tester);
      await tester.tap(find.text('Claim 1 free upload'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not choose a file. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Upload rules'), findsOneWidget);
      expect(writes, isEmpty);
      expect(reads, 1);
      picker.result = () async => [];
      await tester.tap(find.text('Claim 1 free upload'));
      await tester.pumpAndSettle();
      expect(picker.calls, 2);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    },
  );

  testWidgets(
    'confirmed upload refreshes the allowance and displays the created test',
    (tester) async {
      picker.result = () async => [_SelectedFile()];
      uploadWait = Completer<void>();
      await mount(tester);
      await tester.tap(find.text('Claim 1 free upload'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(writes, hasLength(1));
      expect(find.text('Converted revision'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Claim 1 free upload'),
            )
            .onPressed,
        isNull,
      );
      listData = {
        'papers': [created(), existing()],
        'quota': quota(remaining: 0),
      };
      uploadWait!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Converted revision'), findsOneWidget);
      expect(find.text('Your papers (2)'), findsOneWidget);
      expect(find.text('Free upload used'), findsOneWidget);
      expect(find.text('Claim 1 free upload'), findsNothing);
      expect(writes, hasLength(1));
      expect(reads, 2);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    },
  );

  testWidgets(
    'conversion failure reports the server error and keeps existing papers',
    (tester) async {
      picker.result = () async => [_SelectedFile()];
      uploadStatus = 422;
      uploadData = {'error': 'No valid questions were found.'};
      await mount(tester);
      await tester.tap(find.text('Claim 1 free upload'));
      await tester.pumpAndSettle();
      expect(find.text('No valid questions were found.'), findsOneWidget);
      expect(find.text('Existing revision'), findsOneWidget);
      expect(find.text('Your papers (1)'), findsOneWidget);
      expect(find.text('Converted revision'), findsNothing);
      expect(find.text('Claim 1 free upload'), findsOneWidget);
      expect(writes, hasLength(1));
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    },
  );
}
