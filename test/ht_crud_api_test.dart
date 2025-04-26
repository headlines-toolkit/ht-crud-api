//
// ignore_for_file: inference_failure_on_collection_literal, inference_failure_on_function_invocation, lines_longer_than_80_chars, prefer_constructors_over_static_methods, avoid_equals_and_hash_code_on_mutable_classes

import 'package:ht_data_api/ht_data_api.dart';
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
      throw const FormatException(
        'Missing required fields in JSON for _TestModel',
      );
    }
    return _TestModel(id: json['id'] as String, name: json['name'] as String);
  }

  static Map<String, dynamic> toJson(_TestModel item) {
    return {'id': item.id, 'name': item.name};
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
    late HtDataApi<_TestModel> crudApi;
    late HtDataApi<_TestModel> crudApiFromJsonThrows;
    late HtDataApi<_TestModel> crudApiToJsonThrows;

    const testEndpoint = '/test-items';
    const testId = 'item-123';
    const testModel = _TestModel(id: testId, name: 'Test Name');
    final testModelJson = _TestModel.toJson(testModel);
    final testModelList = [testModel];
    final testModelListJson = [testModelJson];
    final genericException = Exception('Something unexpected happened');

    setUp(() {
      mockHttpClient = MockHtHttpClient();
      crudApi = HtDataApi<_TestModel>(
        httpClient: mockHttpClient,
        endpointPath: testEndpoint,
        fromJson: _TestModel.fromJson,
        toJson: _TestModel.toJson,
      );
      crudApiFromJsonThrows = HtDataApi<_TestModel>(
        httpClient: mockHttpClient,
        endpointPath: testEndpoint,
        fromJson: _mockFromJsonThrows,
        toJson: _TestModel.toJson,
      );
      crudApiToJsonThrows = HtDataApi<_TestModel>(
        httpClient: mockHttpClient,
        endpointPath: testEndpoint,
        fromJson: _TestModel.fromJson,
        toJson: _mockToJsonThrows,
      );
    });

    // --- Create Tests ---
    group('create', () {
      // Helper to stub successful post
      void stubPostSuccess() {
        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            testEndpoint,
            data: testModelJson,
          ),
        ).thenAnswer((_) async => testModelJson);
      }

      // Helper to stub failed post
      void stubPostFailure(Exception exception) {
        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            testEndpoint,
            data: testModelJson,
          ),
        ).thenThrow(exception);
      }

      test(
        'should call httpClient.post and return deserialized model on success',
        () async {
          stubPostSuccess();
          final result = await crudApi.create(testModel);
          expect(result, equals(testModel));
          verify(
            () => mockHttpClient.post<Map<String, dynamic>>(
              testEndpoint,
              data: testModelJson,
            ),
          ).called(1);
        },
      );

      test('should throw HtHttpException when httpClient.post fails', () async {
        const exception = BadRequestException('Invalid data');
        stubPostFailure(exception);
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
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              'Exception: toJson failed',
            ),
          ),
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
      test(
        'should throw generic Exception when httpClient.post throws generic',
        () async {
          final exception = genericException;
          stubPostFailure(exception); // Stub with generic exception
          expect(
            () => crudApi.create(testModel),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Something unexpected happened',
              ),
            ),
          );
          verify(
            () => mockHttpClient.post<Map<String, dynamic>>(
              testEndpoint,
              data: testModelJson,
            ),
          ).called(1);
        },
      );
    });

    // --- Read Tests ---
    group('read', () {
      const path = '$testEndpoint/$testId';

      void stubGetSuccess() {
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(path),
        ).thenAnswer((_) async => testModelJson);
      }

      void stubGetFailure(Exception exception) {
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(path),
        ).thenThrow(exception);
      }

      test(
        'should call httpClient.get and return deserialized model on success',
        () async {
          stubGetSuccess();
          final result = await crudApi.read(testId);
          expect(result, equals(testModel));
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(path),
          ).called(1);
        },
      );

      test('should throw HtHttpException when httpClient.get fails', () async {
        const exception = NotFoundException('Item not found');
        stubGetFailure(exception);
        expect(() => crudApi.read(testId), throwsA(isA<NotFoundException>()));
        verify(() => mockHttpClient.get<Map<String, dynamic>>(path)).called(1);
      });

      test('should throw generic Exception when fromJson fails', () async {
        stubGetSuccess(); // HTTP call must succeed to reach fromJson
        expect(
          () => crudApiFromJsonThrows.read(testId),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              'Exception: fromJson failed',
            ),
          ),
        );
        verify(() => mockHttpClient.get<Map<String, dynamic>>(path)).called(1);
      });

      // New test: generic exception from http client
      test(
        'should throw generic Exception when httpClient.get throws generic',
        () async {
          final exception = genericException;
          stubGetFailure(exception); // Stub with generic exception
          expect(
            () => crudApi.read(testId),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Something unexpected happened',
              ),
            ),
          );
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(path),
          ).called(1);
        },
      );
    });

    // --- ReadAll Tests ---
    group('readAll', () {
      // Updated helper to accept queryParameters
      void stubGetAllSuccess({
        List<dynamic> response = const [],
        Map<String, dynamic>? queryParameters,
      }) {
        when(
          () => mockHttpClient.get<List<dynamic>>(
            testEndpoint,
            queryParameters: queryParameters ?? {}, // Pass query params
          ),
        ).thenAnswer((_) async => response);
      }

      // Updated helper to accept queryParameters
      void stubGetAllFailure({
        required Exception exception,
        Map<String, dynamic>? queryParameters,
      }) {
        when(
          () => mockHttpClient.get<List<dynamic>>(
            testEndpoint,
            queryParameters: queryParameters ?? {}, // Pass query params
          ),
        ).thenThrow(exception);
      }

      test(
          'should call httpClient.get with empty query and return list '
          'on success', () async {
        // Verify empty query map is passed by default
        stubGetAllSuccess(
          response: testModelListJson,
          queryParameters: {},
        );
        final result = await crudApi.readAll();
        expect(result, equals(testModelList));
        verify(
          () => mockHttpClient.get<List<dynamic>>(
            testEndpoint,
            queryParameters: {}, // Expect empty map
          ),
        ).called(1);
      });

      // New test for pagination parameters
      test(
          'should call httpClient.get with pagination query and return list '
          'on success', () async {
        const startAfterId = 'item-100';
        const limit = 10;
        final queryParams = {'startAfterId': startAfterId, 'limit': limit};
        stubGetAllSuccess(
          response: testModelListJson,
          queryParameters: queryParams,
        );
        final result = await crudApi.readAll(
          startAfterId: startAfterId,
          limit: limit,
        );
        expect(result, equals(testModelList));
        verify(
          () => mockHttpClient.get<List<dynamic>>(
            testEndpoint,
            queryParameters: queryParams, // Expect pagination params
          ),
        ).called(1);
      });

      test('should throw HtHttpException when httpClient.get fails', () async {
        const exception = ServerException('Server error');
        // Verify empty query map is passed by default on failure too
        stubGetAllFailure(exception: exception, queryParameters: {});
        expect(() => crudApi.readAll(), throwsA(isA<ServerException>()));
        verify(
          () => mockHttpClient.get<List<dynamic>>(
            testEndpoint,
            queryParameters: {}, // Expect empty map
          ),
        ).called(1);
      });

      test(
        'should throw FormatException when list item is not a Map',
        () async {
          // Verify empty query map is passed by default
          stubGetAllSuccess(
            response: [testModelJson, 123], // Invalid item
            queryParameters: {},
          );
          expect(() => crudApi.readAll(), throwsA(isA<FormatException>()));
          verify(
            () => mockHttpClient.get<List<dynamic>>(
              testEndpoint,
              queryParameters: {}, // Expect empty map
            ),
          ).called(1);
        },
      );

      test(
        'should throw generic Exception when fromJson fails during mapping',
        () async {
          // Verify empty query map is passed by default
          stubGetAllSuccess(
            response: testModelListJson, // Valid list from API
            queryParameters: {},
          );
          expect(
            () => crudApiFromJsonThrows.readAll(),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: fromJson failed',
              ),
            ),
          );
          verify(
            () => mockHttpClient.get<List<dynamic>>(
              testEndpoint,
              queryParameters: {}, // Expect empty map
            ),
          ).called(1);
        },
      );

      test(
        'should throw generic Exception when httpClient throws generic error',
        () async {
          final exception = genericException;
          // Verify empty query map is passed by default on failure too
          stubGetAllFailure(exception: exception, queryParameters: {});
          expect(
            () => crudApi.readAll(),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Something unexpected happened',
              ),
            ),
          );
          verify(
            () => mockHttpClient.get<List<dynamic>>(
              testEndpoint,
              queryParameters: {}, // Expect empty map
            ),
          ).called(1);
        },
      );
    });

    // --- ReadAllByQuery Tests ---
    group('readAllByQuery', () {
      final testQuery = {'category': 'test', 'active': true};
      const testStartAfterId = 'item-200';
      const testLimit = 5;
      final testQueryWithPagination = {
        ...testQuery,
        'startAfterId': testStartAfterId,
        'limit': testLimit,
      };

      // Helper for successful query
      void stubGetByQuerySuccess({
        required Map<String, dynamic> queryParameters,
        List<dynamic> response = const [],
      }) {
        when(
          () => mockHttpClient.get<List<dynamic>>(
            testEndpoint,
            queryParameters: queryParameters,
          ),
        ).thenAnswer((_) async => response);
      }

      // Helper for failed query
      void stubGetByQueryFailure({
        required Exception exception,
        required Map<String, dynamic> queryParameters,
      }) {
        when(
          () => mockHttpClient.get<List<dynamic>>(
            testEndpoint,
            queryParameters: queryParameters,
          ),
        ).thenThrow(exception);
      }

      test(
          'should call httpClient.get with query and return list '
          'on success', () async {
        stubGetByQuerySuccess(
          response: testModelListJson,
          queryParameters: testQuery,
        );
        final result = await crudApi.readAllByQuery(testQuery);
        expect(result, equals(testModelList));
        verify(
          () => mockHttpClient.get<List<dynamic>>(
            testEndpoint,
            queryParameters: testQuery,
          ),
        ).called(1);
      });

      test(
          'should call httpClient.get with query and pagination and return list '
          'on success', () async {
        stubGetByQuerySuccess(
          response: testModelListJson,
          queryParameters: testQueryWithPagination,
        );
        final result = await crudApi.readAllByQuery(
          testQuery,
          startAfterId: testStartAfterId,
          limit: testLimit,
        );
        expect(result, equals(testModelList));
        verify(
          () => mockHttpClient.get<List<dynamic>>(
            testEndpoint,
            queryParameters: testQueryWithPagination,
          ),
        ).called(1);
      });

      test('should throw HtHttpException when httpClient.get fails', () async {
        const exception = ServerException('Server error');
        stubGetByQueryFailure(
          exception: exception,
          queryParameters: testQuery,
        );
        expect(
          () => crudApi.readAllByQuery(testQuery),
          throwsA(isA<ServerException>()),
        );
        verify(
          () => mockHttpClient.get<List<dynamic>>(
            testEndpoint,
            queryParameters: testQuery,
          ),
        ).called(1);
      });

      test(
        'should throw FormatException when list item is not a Map',
        () async {
          stubGetByQuerySuccess(
            response: [testModelJson, 123], // Invalid item
            queryParameters: testQuery,
          );
          expect(
            () => crudApi.readAllByQuery(testQuery),
            throwsA(isA<FormatException>()),
          );
          verify(
            () => mockHttpClient.get<List<dynamic>>(
              testEndpoint,
              queryParameters: testQuery,
            ),
          ).called(1);
        },
      );

      test(
        'should throw generic Exception when fromJson fails during mapping',
        () async {
          stubGetByQuerySuccess(
            response: testModelListJson, // Valid list from API
            queryParameters: testQuery,
          );
          expect(
            () => crudApiFromJsonThrows.readAllByQuery(testQuery),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: fromJson failed',
              ),
            ),
          );
          verify(
            () => mockHttpClient.get<List<dynamic>>(
              testEndpoint,
              queryParameters: testQuery,
            ),
          ).called(1);
        },
      );

      test(
        'should throw generic Exception when httpClient throws generic error',
        () async {
          final exception = genericException;
          stubGetByQueryFailure(
            exception: exception,
            queryParameters: testQuery,
          );
          expect(
            () => crudApi.readAllByQuery(testQuery),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Something unexpected happened',
              ),
            ),
          );
          verify(
            () => mockHttpClient.get<List<dynamic>>(
              testEndpoint,
              queryParameters: testQuery,
            ),
          ).called(1);
        },
      );
    });

    // --- Update Tests ---
    group('update', () {
      const path = '$testEndpoint/$testId';
      const updatedModel = _TestModel(id: testId, name: 'Updated Name');
      final updatedModelJson = _TestModel.toJson(updatedModel);

      void stubPutSuccess() {
        when(
          () => mockHttpClient.put<Map<String, dynamic>>(
            path,
            data: updatedModelJson, // Use updated model here for stubbing
          ),
        ).thenAnswer((_) async => updatedModelJson);
      }

      test(
        'should call httpClient.put and return deserialized model on success',
        () async {
          stubPutSuccess();
          final result = await crudApi.update(testId, updatedModel);
          expect(result, equals(updatedModel));
          verify(
            () => mockHttpClient.put<Map<String, dynamic>>(
              path,
              data: updatedModelJson,
            ),
          ).called(1);
        },
      );

      test('should throw HtHttpException when httpClient.put fails', () async {
        const exception = UnauthorizedException('Auth failed');
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
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              'Exception: toJson failed',
            ),
          ),
        );
        verifyNever(
          () => mockHttpClient.put<Map<String, dynamic>>(
            any(), // Match any path
            data: any(named: 'data'), // Match any data
          ),
        );
      });

      // New test: generic exception from http client
      test(
        'should throw generic Exception when httpClient.put throws generic',
        () async {
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
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Something unexpected happened',
              ),
            ),
          );
          verify(
            () => mockHttpClient.put<Map<String, dynamic>>(
              path,
              data: testModelJson,
            ),
          ).called(1);
        },
      );
    });

    // --- Delete Tests ---
    group('delete', () {
      const path = '$testEndpoint/$testId';

      void stubDeleteSuccess() {
        when(
          () => mockHttpClient.delete<dynamic>(path),
        ).thenAnswer((_) async => null); // Return null for success
      }

      void stubDeleteFailure(Exception exception) {
        when(() => mockHttpClient.delete<dynamic>(path)).thenThrow(exception);
      }

      test(
        'should call httpClient.delete and complete normally on success',
        () async {
          stubDeleteSuccess();
          await crudApi.delete(testId); // Should complete without error
          verify(() => mockHttpClient.delete<dynamic>(path)).called(1);
        },
      );

      test(
        'should throw HtHttpException when httpClient.delete fails',
        () async {
          const exception = ForbiddenException('Permission denied');
          stubDeleteFailure(exception);
          expect(
            () => crudApi.delete(testId),
            throwsA(isA<ForbiddenException>()),
          );
          verify(() => mockHttpClient.delete<dynamic>(path)).called(1);
        },
      );

      test(
        'should throw generic Exception when httpClient.delete throws generic error',
        () async {
          final exception = genericException;
          stubDeleteFailure(exception);
          expect(
            () => crudApi.delete(testId),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Something unexpected happened',
              ),
            ),
          );
          verify(() => mockHttpClient.delete<dynamic>(path)).called(1);
        },
      );
    });
  });
}
