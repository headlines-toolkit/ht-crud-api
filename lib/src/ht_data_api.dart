import 'package:ht_data_client/ht_data_client.dart';
import 'package:ht_http_client/ht_http_client.dart';
import 'package:ht_shared/ht_shared.dart';

/// {@template ht_data_api}
/// An implementation of [HtDataClient] that uses an [HtHttpClient] for
/// communication with a data resource endpoint.
///
/// This class provides concrete implementations for the data access methods
/// defined in [HtDataClient], handling the underlying HTTP requests and
/// managing serialization/deserialization via provided [FromJson] and [ToJson]
/// functions.
///
/// It requires the base path for the resource endpoint (e.g., '/users', '/products').
/// {@endtemplate}
class HtDataApi<T> implements HtDataClient<T> {
  /// {@macro ht_data_api}
  const HtDataApi({
    required HtHttpClient httpClient,
    required String endpointPath,
    required FromJson<T> fromJson,
    required ToJson<T> toJson,
  })  : _httpClient = httpClient,
        _endpointPath = endpointPath,
        _fromJson = fromJson,
        _toJson = toJson;

  final HtHttpClient _httpClient;
  final String _endpointPath;
  final FromJson<T> _fromJson;
  final ToJson<T> _toJson;

  /// Creates a new resource item of type [T].
  ///
  /// Sends POST request to the base [_endpointPath] with the serialized [item].
  /// Returns the created item, potentially populated with server-assigned data.
  ///
  /// Throws [HtHttpException] or its subtypes on underlying HTTP communication
  /// failure. Exceptions during serialization ([_toJson]) or deserialization
  /// ([_fromJson]) will also propagate. These exceptions are intended to be
  /// handled by the caller (e.g., Repository or BLoC layer).
  @override
  Future<SuccessApiResponse<T>> create(T item) async {
    // Exceptions from _httpClient or _fromJson/_toJson are allowed to propagate.
    final responseData = await _httpClient.post<Map<String, dynamic>>(
      _endpointPath,
      data: _toJson(item),
    );
    // Deserialize the entire envelope
    return SuccessApiResponse.fromJson(
      responseData,
      (json) => _fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Reads a single resource item of type [T] by its unique [id].
  ///
  /// Sends a GET request to `[_endpointPath]/{id}`.
  /// Returns the deserialized item.
  ///
  /// Throws [HtHttpException] or its subtypes (e.g., [NotFoundException]) on
  /// underlying HTTP communication failure. Exceptions during deserialization
  /// ([_fromJson]) will also propagate. These exceptions are intended to be
  /// handled by the caller.
  @override
  Future<SuccessApiResponse<T>> read(String id) async {
    // Exceptions from _httpClient or _fromJson are allowed to propagate.
    final responseData = await _httpClient.get<Map<String, dynamic>>(
      '$_endpointPath/$id',
    );
    // Deserialize the entire envelope
    return SuccessApiResponse.fromJson(
      responseData,
      (json) => _fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Reads all resource items of type [T].
  ///
  /// Sends a GET request to the base [_endpointPath]. Expects a JSON array.
  /// Returns a list of deserialized items.
  ///
  /// Throws [HtHttpException] or its subtypes on underlying HTTP communication
  /// failure. Can also throw [FormatException] if the received data structure
  /// is incorrect (e.g., list item is not a Map) or other exceptions during
  /// deserialization ([_fromJson]). These exceptions are intended to be handled
  /// by the caller.
  @override
  Future<SuccessApiResponse<PaginatedResponse<T>>> readAll({
    String? startAfterId,
    int? limit,
  }) async {
    // Exceptions from _httpClient are allowed to propagate.
    final responseData = await _httpClient.get<Map<String, dynamic>>(
      _endpointPath,
      queryParameters: {
        if (startAfterId != null) 'startAfterId': startAfterId,
        if (limit != null) 'limit': limit,
      },
    );

    // Deserialize the entire envelope, including the PaginatedResponse
    return SuccessApiResponse.fromJson(
      responseData,
      (json) => PaginatedResponse.fromJson(
        json! as Map<String, dynamic>,
        (itemJson) => _fromJson(itemJson! as Map<String, dynamic>),
      ),
    );
  }

  /// Reads multiple resource items of type [T] based on a [query].
  ///
  /// Sends a GET request to the base [_endpointPath] with the
  /// provided [query] parameters and optional pagination
  /// parameters ([startAfterId], [limit]).
  ///
  /// Returns a list of deserialized items matching the query.
  ///
  /// Throws [HtHttpException] or its subtypes on underlying HTTP communication
  /// failure. Can also throw [FormatException] if the received data structure
  /// is incorrect (e.g., list item is not a Map) or other exceptions during
  /// deserialization ([_fromJson]). These exceptions are intended to be handled
  /// by the caller.
  @override
  Future<SuccessApiResponse<PaginatedResponse<T>>> readAllByQuery(
    Map<String, dynamic> query, {
    String? startAfterId,
    int? limit,
  }) async {
    // Exceptions from _httpClient are allowed to propagate.
    final responseData = await _httpClient.get<Map<String, dynamic>>(
      _endpointPath,
      queryParameters: {
        ...query,
        if (startAfterId != null) 'startAfterId': startAfterId,
        if (limit != null) 'limit': limit,
      },
    );

    // Deserialize the entire envelope, including the PaginatedResponse
    return SuccessApiResponse.fromJson(
      responseData,
      (json) => PaginatedResponse.fromJson(
        json! as Map<String, dynamic>,
        (itemJson) => _fromJson(itemJson! as Map<String, dynamic>),
      ),
    );
  }

  /// Updates an existing resource item of type [T] identified by [id].
  ///
  /// Sends a PUT request to `[_endpointPath]/{id}` with the serialized [item].
  /// Returns the updated item as returned by the server.
  ///
  /// Throws [HtHttpException] or its subtypes (e.g., [NotFoundException]) on
  /// underlying HTTP communication failure. Exceptions during serialization
  /// ([_toJson]) or deserialization ([_fromJson]) will also propagate. These
  /// exceptions are intended to be handled by the caller.
  @override
  Future<SuccessApiResponse<T>> update(String id, T item) async {
    // Exceptions from _httpClient or _fromJson/_toJson are allowed to propagate.
    final responseData = await _httpClient.put<Map<String, dynamic>>(
      '$_endpointPath/$id',
      data: _toJson(item),
    );
    // Deserialize the entire envelope
    return SuccessApiResponse.fromJson(
      responseData,
      (json) => _fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Deletes a resource item identified by [id].
  ///
  /// Sends a DELETE request to `[_endpointPath]/{id}`. Returns `void`.
  ///
  /// Throws [HtHttpException] or its subtypes (e.g., [NotFoundException]) on
  /// underlying HTTP communication failure. These exceptions are intended to be
  /// handled by the caller.
  @override
  Future<void> delete(String id) async {
    // Exceptions from _httpClient are allowed to propagate.
    // We expect no content, but use <dynamic> for flexibility.
    await _httpClient.delete<dynamic>('$_endpointPath/$id');
  }
}
