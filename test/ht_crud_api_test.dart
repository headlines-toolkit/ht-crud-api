import 'package:ht_crud_api/ht_crud_api.dart';
import 'package:ht_http_client/ht_http_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// --- Mock HttpClient ---
class MockHtHttpClient extends Mock implements HtHttpClient {}

// --- Mock Functions for Error Simulation ---
_TestModel _mockFromJsonThrows(Map<String, dynamic> json) =>
    throw Exception('fromJson failed');
Map<String, dynamic> _mockToJsonThrows(_TestModel item) =>
    throw Exception('toJson failed');

// --- Dummy Model for Testing ---
class _TestModel {
  const _TestModel({required this.id, required this.name});

  final String id;
  final String name;

  static _TestModel fromJson(Map<String, dynamic> json) {
    if (json['id'] == null || json['name'] == null) {
      throw FormatException('Missing required fields in JSON for _TestModel');
    }
    return _TestModel(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  static Map<String, dynamic> toJson(_TestModel item) {
    return {
      'id': item.id,
      'name': item.name,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TestModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => '_TestModel(id: $id, name: $name)';
}

void main() {
  // Register fallbacks for argument matchers used in stubs/verification
  // This prevents errors if matchers are used before specific values
  setUpAll(() {
    registerFallbackValue({});
    registerFallbackValue('');
  });

  group('CrudApi', () {
    late HtHttpClient mockHttpClient;
    late CrudApi<_TestModel> crudApi;
    late CrudApi<_TestModel> crudApiFromJsonThrows;
    late CrudApi<_TestModel> crudApiToJsonThrows;

    const testEndpoint = '/test-items';
    const testId = 'item-123';
    final testModel = _TestModel(id: testId, name: 'Test Name');
    final testModelJson = _TestModel.toJson(testModel);
    final testModelList = [testModel];
    final testModelListJson = [testModelJson];
    final genericException = Exception('Something unexpected happened');

    setUp(() {
      mockHttpClient = MockHtHttpClient();
      crudApi = CrudApi<_TestModel>(
        httpClient: mockHttpClient,
        endpointPath: testEndpoint,
        fromJson: _TestModel.fromJson,
        toJson: _TestModel.toJson,
      );
      crudApiFromJsonThrows = CrudApi<_TestModel>(
        httpClient: mockHttpClient,
        endpointPath: testEndpoint,
        fromJson: _mockFromJsonThrows,
        toJson: _TestModel.toJson,
      );
      crudApiToJsonThrows = CrudApi<_TestModel>(
        httpClient: mockHttpClient,
        endpointPath: testEndpoint,
        fromJson: _TestModel.fromJson,
        toJson: _mockToJsonThrows,
      );
    });

    // --- Create Tests ---
    group('create', () {
      // Helper to stub successful post
      void _stubPostSuccess() {
        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            testEndpoint,
            data: testModelJson,
          ),
        ).thenAnswer((_) async => testModelJson);
      }

      // Helper to stub failed post
      void _stubPostFailure(Exception exception) {
         when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            testEndpoint,
            data: testModelJson,
          ),
        ).thenThrow(exception);
      }

      test('should call httpClient.post and return deserialized model on success',
          () async {
        _stubPostSuccess();
        final result = await crudApi.create(testModel);
        expect(result, equals(testModel));
        verify(
          () => mockHttpClient.post<Map<String, dynamic>>(
            testEndpoint,
            data: testModelJson,
          ),
        ).called(1);
      });

      test('should throw HtHttpException when httpClient.post fails', () async {
        final exception = BadRequestException('Invalid data');
        _stubPostFailure(exception);
        expect(
          () => crudApi.create(testModel),
          throwsA(isA<BadRequestException>()),
        );
         verify(
          () => mockHttpClient.post<Map<String, dynamic>>(
            testEndpoint,
            data: testModelJson,
          ),
        ).called(1);
      });

      test('should throw generic Exception when toJson fails', () async {
        // No stubbing needed as http client is not called
        expect(
          () => crudApiToJsonThrows.create(testModel),
          throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', 'Exception: toJson failed')),
        );
        // Correct verifyNever usage
        verifyNever(
          () => mockHttpClient.post<Map<String, dynamic>>(
            any(), // Match any path
            data: any(named: 'data'), // Match any data using named argument
          ),
        );
      });

       // New test: generic exception from http client
       test('should throw generic Exception when httpClient.post throws generic', () async {
         final exception = genericException;
         _stubPostFailure(exception); // Stub with generic exception
         expect(
           () => crudApi.create(testModel),
           throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', 'Exception: Something unexpected happened')),
         );
         verify(
           () => mockHttpClient.post<Map<String, dynamic>>(
             testEndpoint,
             data: testModelJson,
           ),
         ).called(1);
       });
    });

    // --- Read Tests ---
    group('read', () {
      final path = '$testEndpoint/$testId';

      void _stubGetSuccess() {
         when(() => mockHttpClient.get<Map<String, dynamic>>(path))
            .thenAnswer((_) async => testModelJson);
      }
       void _stubGetFailure(Exception exception) {
         when(() => mockHttpClient.get<Map<String, dynamic>>(path))
            .thenThrow(exception);
      }

      test('should call httpClient.get and return deserialized model on success',
          () async {
        _stubGetSuccess();
        final result = await crudApi.read(testId);
        expect(result, equals(testModel));
        verify(() => mockHttpClient.get<Map<String, dynamic>>(path)).called(1);
      });

      test('should throw HtHttpException when httpClient.get fails', () async {
        final exception = NotFoundException('Item not found');
        _stubGetFailure(exception);
        expect(
          () => crudApi.read(testId),
          throwsA(isA<NotFoundException>()),
        );
        verify(() => mockHttpClient.get<Map<String, dynamic>>(path)).called(1);
      });

      test('should throw generic Exception when fromJson fails', () async {
        _stubGetSuccess(); // HTTP call must succeed to reach fromJson
        expect(
          () => crudApiFromJsonThrows.read(testId),
           throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', 'Exception: fromJson failed')),
        );
         verify(() => mockHttpClient.get<Map<String, dynamic>>(path)).called(1);
      });

       // New test: generic exception from http client
       test('should throw generic Exception when httpClient.get throws generic', () async {
         final exception = genericException;
         _stubGetFailure(exception); // Stub with generic exception
         expect(
           () => crudApi.read(testId),
           throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', 'Exception: Something unexpected happened')),
         );
         verify(() => mockHttpClient.get<Map<String, dynamic>>(path)).called(1);
       });
    });

    // --- ReadAll Tests ---
    group('readAll', () {
       void _stubGetAllSuccess({List<dynamic> response = const []}) {
         when(() => mockHttpClient.get<List<dynamic>>(testEndpoint))
            .thenAnswer((_) async => response);
       }
        void _stubGetAllFailure(Exception exception) {
          when(() => mockHttpClient.get<List<dynamic>>(testEndpoint))
            .thenThrow(exception);
       }

      test(
          'should call httpClient.get and return list of deserialized models '
          'on success', () async {
        _stubGetAllSuccess(response: testModelListJson);
        final result = await crudApi.readAll();
        expect(result, equals(testModelList));
        verify(() => mockHttpClient.get<List<dynamic>>(testEndpoint))
            .called(1);
      });

      test('should throw HtHttpException when httpClient.get fails', () async {
        final exception = ServerException('Server error');
        _stubGetAllFailure(exception);
        expect(
          () => crudApi.readAll(),
          throwsA(isA<ServerException>()),
        );
         verify(() => mockHttpClient.get<List<dynamic>>(testEndpoint))
            .called(1);
      });

       test('should throw FormatException when list item is not a Map', () async {
        _stubGetAllSuccess(response: [testModelJson, 123]); // Invalid item
        expect(
          () => crudApi.readAll(),
          throwsA(isA<FormatException>()),
        );
         verify(() => mockHttpClient.get<List<dynamic>>(testEndpoint))
            .called(1);
      });

       test('should throw generic Exception when fromJson fails during mapping', () async {
         _stubGetAllSuccess(response: testModelListJson); // Valid list from API
         expect(
           () => crudApiFromJsonThrows.readAll(),
           throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', 'Exception: fromJson failed')),
         );
         verify(() => mockHttpClient.get<List<dynamic>>(testEndpoint)).called(1);
       });

       test('should throw generic Exception when httpClient throws generic error', () async {
         final exception = genericException;
         _stubGetAllFailure(exception);
         expect(
           () => crudApi.readAll(),
           throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', 'Exception: Something unexpected happened')),
         );
         verify(() => mockHttpClient.get<List<dynamic>>(testEndpoint)).called(1);
       });
    });

    // --- Update Tests ---
    group('update', () {
       final path = '$testEndpoint/$testId';
       final updatedModel = _TestModel(id: testId, name: 'Updated Name');
       final updatedModelJson = _TestModel.toJson(updatedModel);

       void _stubPutSuccess() {
          when(
           () => mockHttpClient.put<Map<String, dynamic>>(
             path,
             data: updatedModelJson, // Use updated model here for stubbing
           ),
         ).thenAnswer((_) async => updatedModelJson);
       }

       void _stubPutFailure(Exception exception) {
          when(
           () => mockHttpClient.put<Map<String, dynamic>>(
             path,
             data: any(named: 'data'), // Match any data for failure case
           ),
         ).thenThrow(exception);
       }

      test('should call httpClient.put and return deserialized model on success',
          () async {
        _stubPutSuccess();
        final result = await crudApi.update(testId, updatedModel);
        expect(result, equals(updatedModel));
        verify(
          () => mockHttpClient.put<Map<String, dynamic>>(
            path,
            data: updatedModelJson,
          ),
        ).called(1);
      });

      test('should throw HtHttpException when httpClient.put fails', () async {
        final exception = UnauthorizedException('Auth failed');
        // Stub with the original model being sent, as that's what update receives
         when(
           () => mockHttpClient.put<Map<String, dynamic>>(
             path,
             data: testModelJson, // Use original model for this failure case
           ),
         ).thenThrow(exception);

        expect(
          () => crudApi.update(testId, testModel), // Call with original model
          throwsA(isA<UnauthorizedException>()),
        );
         verify(
          () => mockHttpClient.put<Map<String, dynamic>>(
            path,
            data: testModelJson,
          ),
        ).called(1);
      });

       test('should throw generic Exception when toJson fails', () async {
         // No stubbing needed
         expect(
           () => crudApiToJsonThrows.update(testId, testModel),
           throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', 'Exception: toJson failed')),
         );
         verifyNever(() => mockHttpClient.put<Map<String, dynamic>>(
              any(), // Match any path
              data: any(named: 'data'), // Match any data
            ));
       });

        // New test: generic exception from http client
       test('should throw generic Exception when httpClient.put throws generic', () async {
         final exception = genericException;
         // Stub with the original model being sent
         when(
           () => mockHttpClient.put<Map<String, dynamic>>(
             path,
             data: testModelJson,
           ),
         ).thenThrow(exception);

         expect(
           () => crudApi.update(testId, testModel),
           throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', 'Exception: Something unexpected happened')),
         );
         verify(
           () => mockHttpClient.put<Map<String, dynamic>>(
             path,
             data: testModelJson,
           ),
         ).called(1);
       });
    });

    // --- Delete Tests ---
    group('delete', () {
       final path = '$testEndpoint/$testId';

       void _stubDeleteSuccess() {
          when(() => mockHttpClient.delete<dynamic>(path))
            .thenAnswer((_) async => null); // Return null for success
       }
       void _stubDeleteFailure(Exception exception) {
          when(() => mockHttpClient.delete<dynamic>(path)).thenThrow(exception);
       }

      test('should call httpClient.delete and complete normally on success',
          () async {
        _stubDeleteSuccess();
        await crudApi.delete(testId); // Should complete without error
        verify(() => mockHttpClient.delete<dynamic>(path)).called(1);
      });

      test('should throw HtHttpException when httpClient.delete fails',
          () async {
        final exception = ForbiddenException('Permission denied');
        _stubDeleteFailure(exception);
        expect(
          () => crudApi.delete(testId),
          throwsA(isA<ForbiddenException>()),
        );
        verify(() => mockHttpClient.delete<dynamic>(path)).called(1);
      });

       test('should throw generic Exception when httpClient.delete throws generic error', () async {
         final exception = genericException;
         _stubDeleteFailure(exception);
         expect(
           () => crudApi.delete(testId),
           throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', 'Exception: Something unexpected happened')),
         );
         verify(() => mockHttpClient.delete<dynamic>(path)).called(1);
       });
    });
  });
}