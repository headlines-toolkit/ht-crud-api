//
// ignore_for_file: inference_failure_on_collection_literal, inference_failure_on_function_invocation, lines_longer_than_80_chars, prefer_constructors_over_static_methods, avoid_equals_and_hash_code_on_mutable_classes

import 'package:ht_data_api/ht_data_api.dart';
import 'package:ht_http_client/ht_http_client.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// --- Mock HttpClient ---
class MockHtHttpClient extends Mock implements HtHttpClient {}

// --- Helper to create a standard success envelope ---
Map<String, dynamic> _createSuccessEnvelope(dynamic data) {
  return {
    'data': data,
    'metadata': null,
  };
}

// --- Helper to create a standard paginated response map ---
Map<String, dynamic> _createPaginatedResponseMap(
  List<dynamic> items, {
  String? cursor,
  bool hasMore = false,
}) {
  return {
    'items': items,
    'cursor': cursor,
    'hasMore': hasMore,
  };
}

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

  group('HtDataApi', () {
    late HtHttpClient mockHttpClient;
    late HtDataApi<_TestModel> htDataApi;
    late HtDataApi<_TestModel> htDataApiFromJsonThrows;
    late HtDataApi<_TestModel> htDataApiToJsonThrows;

    const testEndpoint = '/test-items';
    const testId = 'item-123';
    const testModel = _TestModel(id: testId, name: 'Test Name');
    final testModelJson = _TestModel.toJson(testModel);
    final testModelList = [testModel];
    final testModelListJson = [testModelJson];
    final genericException = Exception('Something unexpected happened');

    // Pre-create enveloped responses for convenience
    final successEnvelopeSingle = _createSuccessEnvelope(testModelJson);
    //
    // ignore: unused_local_variable
    final successEnvelopePaginated = _createSuccessEnvelope(
      _createPaginatedResponseMap(testModelListJson),
    );

    setUp(() {
      mockHttpClient = MockHtHttpClient();
      htDataApi = HtDataApi<_TestModel>(
        httpClient: mockHttpClient,
        endpointPath: testEndpoint,
        fromJson: _TestModel.fromJson,
        toJson: _TestModel.toJson,
      );
      htDataApiFromJsonThrows = HtDataApi<_TestModel>(
        httpClient: mockHttpClient,
        endpointPath: testEndpoint,
        fromJson: _mockFromJsonThrows,
        toJson: _TestModel.toJson,
      );
      htDataApiToJsonThrows = HtDataApi<_TestModel>(
        httpClient: mockHttpClient,
        endpointPath: testEndpoint,
        fromJson: _TestModel.fromJson,
        toJson: _mockToJsonThrows,
      );
    });

    // --- Create Tests ---
    group('create', () {
      // Helper to stub successful post
      // Helper to stub successful post returning an envelope
      void stubPostSuccess() {
        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            testEndpoint,
            data: testModelJson,
          ),
        ).thenAnswer((_) async => successEnvelopeSingle);
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
          final result = await htDataApi.create(testModel);
          expect(result, isA<SuccessApiResponse<_TestModel>>());
          expect(result.data, equals(testModel));
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
          () => htDataApi.create(testModel),
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
          () => htDataApiToJsonThrows.create(testModel),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              'Exception: toJson failed',
            ),
          ),
        );
        verifyNever(
          () => mockHttpClient.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'), // Match any data using named argument
          ),
        );
      });

      // New test: generic exception from http client
      test(
        'should throw generic Exception when httpClient.post throws generic',
        () async {
          final exception = genericException;
          stubPostFailure(exception);
          expect(
            () => htDataApi.create(testModel),
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

      // Helper to stub successful get returning an envelope
      void stubGetSuccess() {
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(path),
        ).thenAnswer((_) async => successEnvelopeSingle);
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
          final result = await htDataApi.read(testId);
          expect(result, isA<SuccessApiResponse<_TestModel>>());
          expect(result.data, equals(testModel));
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(path),
          ).called(1);
        },
      );

      test('should throw HtHttpException when httpClient.get fails', () async {
        const exception = NotFoundException('Item not found');
        stubGetFailure(exception);
        expect(() => htDataApi.read(testId), throwsA(isA<NotFoundException>()));
        verify(() => mockHttpClient.get<Map<String, dynamic>>(path)).called(1);
      });

      test('should throw generic Exception when fromJson fails', () async {
        // Stub needs to return the envelope, even if fromJson will fail
        stubGetSuccess();
        expect(
          () => htDataApiFromJsonThrows.read(testId),
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
          stubGetFailure(exception);
          expect(
            () => htDataApi.read(testId),
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
      // Updated helper to return enveloped paginated response
      void stubGetAllSuccess({
        List<dynamic> items = const [],
        Map<String, dynamic>? queryParameters,
        bool hasMore = false,
        String? cursor,
      }) {
        final paginatedData = _createPaginatedResponseMap(
          items,
          hasMore: hasMore,
          cursor: cursor,
        );
        final envelope = _createSuccessEnvelope(paginatedData);
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            testEndpoint,
            queryParameters: queryParameters ?? {},
          ),
        ).thenAnswer((_) async => envelope);
      }

      // Updated helper for failure, still expects Map
      void stubGetAllFailure({
        required Exception exception,
        Map<String, dynamic>? queryParameters,
      }) {
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            testEndpoint,
            queryParameters: queryParameters ?? {},
          ),
        ).thenThrow(exception);
      }

      test(
          'should call httpClient.get with empty query and return list '
          'on success', () async {
        stubGetAllSuccess(
          items: testModelListJson,
          queryParameters: {},
        );
        final result = await htDataApi.readAll();
        expect(
          result,
          isA<SuccessApiResponse<PaginatedResponse<_TestModel>>>(),
        );
        expect(result.data.items, equals(testModelList));
        expect(result.data.hasMore, isFalse);
        verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
            testEndpoint,
            queryParameters: {},
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
          items: testModelListJson,
          queryParameters: queryParams,
          hasMore: true,
        );
        final result = await htDataApi.readAll(
          startAfterId: startAfterId,
          limit: limit,
        );
        expect(
          result,
          isA<SuccessApiResponse<PaginatedResponse<_TestModel>>>(),
        );
        expect(result.data.items, equals(testModelList));
        expect(result.data.hasMore, isTrue);
        verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
            testEndpoint,
            queryParameters: queryParams,
          ),
        ).called(1);
      });

      test('should throw HtHttpException when httpClient.get fails', () async {
        const exception = ServerException('Server error');
        stubGetAllFailure(exception: exception, queryParameters: {});
        expect(() => htDataApi.readAll(), throwsA(isA<ServerException>()));
        verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
            testEndpoint,
            queryParameters: {},
          ),
        ).called(1);
      });

      test(
        'should throw FormatException when list item is not a Map',
        () async {
          // Stub needs to return envelope with malformed paginated data inside
          final malformedPaginatedData = _createPaginatedResponseMap(
            [testModelJson, 123],
          );
          final envelopeWithMalformedData =
              _createSuccessEnvelope(malformedPaginatedData);
          when(
            () => mockHttpClient.get<Map<String, dynamic>>(
              testEndpoint,
              queryParameters: {},
            ),
          ).thenAnswer((_) async => envelopeWithMalformedData);

          expect(() => htDataApi.readAll(), throwsA(isA<FormatException>()));
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              testEndpoint,
              queryParameters: {},
            ),
          ).called(1);
        },
      );

      test(
        'should throw generic Exception when fromJson fails during mapping',
        () async {
          // Stub needs to return a valid envelope, failure happens in fromJson
          stubGetAllSuccess(
            items: testModelListJson,
            queryParameters: {},
          );
          expect(
            () => htDataApiFromJsonThrows.readAll(),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: fromJson failed',
              ),
            ),
          );
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              testEndpoint,
              queryParameters: {},
            ),
          ).called(1);
        },
      );

      test(
        'should throw generic Exception when httpClient throws generic error',
        () async {
          final exception = genericException;
          stubGetAllFailure(exception: exception, queryParameters: {});
          expect(
            () => htDataApi.readAll(),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Something unexpected happened',
              ),
            ),
          );
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              testEndpoint,
              queryParameters: {},
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

      // Helper for successful query returning enveloped paginated response
      void stubGetByQuerySuccess({
        required Map<String, dynamic> queryParameters,
        List<dynamic> items = const [],
        bool hasMore = false,
        String? cursor,
      }) {
        final paginatedData = _createPaginatedResponseMap(
          items,
          hasMore: hasMore,
          cursor: cursor,
        );
        final envelope = _createSuccessEnvelope(paginatedData);
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            testEndpoint,
            queryParameters: queryParameters,
          ),
        ).thenAnswer((_) async => envelope);
      }

      // Helper for failed query, still expects Map
      void stubGetByQueryFailure({
        required Exception exception,
        required Map<String, dynamic> queryParameters,
      }) {
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            testEndpoint,
            queryParameters: queryParameters,
          ),
        ).thenThrow(exception);
      }

      test(
          'should call httpClient.get with query and return list '
          'on success', () async {
        stubGetByQuerySuccess(
          items: testModelListJson,
          queryParameters: testQuery,
        );
        final result = await htDataApi.readAllByQuery(testQuery);
        expect(
          result,
          isA<SuccessApiResponse<PaginatedResponse<_TestModel>>>(),
        );
        expect(result.data.items, equals(testModelList));
        expect(result.data.hasMore, isFalse);
        verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
            testEndpoint,
            queryParameters: testQuery,
          ),
        ).called(1);
      });

      test(
          'should call httpClient.get with query and pagination and return list '
          'on success', () async {
        stubGetByQuerySuccess(
          items: testModelListJson,
          queryParameters: testQueryWithPagination,
          hasMore: true,
        );
        final result = await htDataApi.readAllByQuery(
          testQuery,
          startAfterId: testStartAfterId,
          limit: testLimit,
        );
        expect(
          result,
          isA<SuccessApiResponse<PaginatedResponse<_TestModel>>>(),
        );
        expect(result.data.items, equals(testModelList));
        expect(result.data.hasMore, isTrue);
        verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
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
          () => htDataApi.readAllByQuery(testQuery),
          throwsA(isA<ServerException>()),
        );
        verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
            testEndpoint,
            queryParameters: testQuery,
          ),
        ).called(1);
      });

      test(
        'should throw FormatException when list item is not a Map',
        () async {
          // Stub needs to return envelope with malformed paginated data inside
          final malformedPaginatedData = _createPaginatedResponseMap(
            [testModelJson, 123],
          );
          final envelopeWithMalformedData =
              _createSuccessEnvelope(malformedPaginatedData);
          when(
            () => mockHttpClient.get<Map<String, dynamic>>(
              testEndpoint,
              queryParameters: testQuery,
            ),
          ).thenAnswer((_) async => envelopeWithMalformedData);

          expect(
            () => htDataApi.readAllByQuery(testQuery),
            throwsA(isA<FormatException>()),
          );
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              testEndpoint,
              queryParameters: testQuery,
            ),
          ).called(1);
        },
      );

      test(
        'should throw generic Exception when fromJson fails during mapping',
        () async {
          // Stub needs to return a valid envelope, failure happens in fromJson
          stubGetByQuerySuccess(
            items: testModelListJson,
            queryParameters: testQuery,
          );
          expect(
            () => htDataApiFromJsonThrows.readAllByQuery(testQuery),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: fromJson failed',
              ),
            ),
          );
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
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
            () => htDataApi.readAllByQuery(testQuery),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Something unexpected happened',
              ),
            ),
          );
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
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
      final successEnvelopeUpdated = _createSuccessEnvelope(updatedModelJson);

      // Helper to stub successful put returning an envelope
      void stubPutSuccess() {
        when(
          () => mockHttpClient.put<Map<String, dynamic>>(
            path,
            data: updatedModelJson,
          ),
        ).thenAnswer((_) async => successEnvelopeUpdated);
      }

      test(
        'should call httpClient.put and return deserialized model on success',
        () async {
          stubPutSuccess();
          final result = await htDataApi.update(testId, updatedModel);
          expect(result, isA<SuccessApiResponse<_TestModel>>());
          expect(result.data, equals(updatedModel));
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
            data: testModelJson,
          ),
        ).thenThrow(exception);

        expect(
          () => htDataApi.update(testId, testModel),
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
          () => htDataApiToJsonThrows.update(testId, testModel),
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
            data: any(named: 'data'),
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
            () => htDataApi.update(testId, testModel),
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
        ).thenAnswer((_) async => null);
      }

      void stubDeleteFailure(Exception exception) {
        when(() => mockHttpClient.delete<dynamic>(path)).thenThrow(exception);
      }

      test(
        'should call httpClient.delete and complete normally on success',
        () async {
          stubDeleteSuccess();
          await htDataApi.delete(testId);
          verify(() => mockHttpClient.delete<dynamic>(path)).called(1);
        },
      );

      test(
        'should throw HtHttpException when httpClient.delete fails',
        () async {
          const exception = ForbiddenException('Permission denied');
          stubDeleteFailure(exception);
          expect(
            () => htDataApi.delete(testId),
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
            () => htDataApi.delete(testId),
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
