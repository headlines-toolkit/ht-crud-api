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
/// It requires the model name (e.g., 'headline', 'category') to target the
/// correct resource via the unified API endpoint.
/// {@endtemplate}
class HtDataApi<T> implements HtDataClient<T> {
  /// {@macro ht_data_api}
  const HtDataApi({
    required HtHttpClient httpClient,
    required String modelName,
    required FromJson<T> fromJson,
    required ToJson<T> toJson,
  })  : _httpClient = httpClient,
        _modelName = modelName,
        _fromJson = fromJson,
        _toJson = toJson;

  /// The base path for the unified data API endpoint.
  static const String _basePath = '/api/v1/data';

  final HtHttpClient _httpClient;
  final String _modelName;
  final FromJson<T> _fromJson;
  final ToJson<T> _toJson;

  /// Creates a new resource item of type [T].
  ///
  /// - [userId]: The unique identifier of the user performing the operation.
  ///   If `null`, the operation may be considered a global creation (e.g.,
  ///   by an admin), depending on the resource type [T]. Implementations
  ///   must handle the `null` case appropriately.
  /// - [item]: The resource item to create.
  ///
  /// Sends a POST request to the unified API endpoint `[_basePath]` with
  /// the serialized [item] data and the `model` query parameter set to
  /// [_modelName]. Includes the `userId` query parameter if provided.
  ///
  /// Example Request (user-scoped): `POST /api/v1/data?model=headline&userId=user123`
  /// Example Request (global): `POST /api/v1/data?model=headline`
  ///
  /// Returns a [SuccessApiResponse] containing the created item, potentially
  /// populated with server-assigned data (like an ID).
  ///
  /// Throws [HtHttpException] or its subtypes on underlying HTTP communication
  /// failure. Exceptions during serialization ([_toJson]) or deserialization
  /// ([_fromJson]) will also propagate. These exceptions are intended to be
  /// handled by the caller (e.g., Repository or BLoC layer).
  @override
  Future<SuccessApiResponse<T>> create({
    required T item,
    String? userId,
  }) async {
    // Exceptions from _httpClient or _fromJson/_toJson are allowed to propagate.
    final queryParameters = <String, dynamic>{
      'model': _modelName,
      if (userId != null) 'userId': userId,
    };
    final responseData = await _httpClient.post<Map<String, dynamic>>(
      _basePath,
      data: _toJson(item),
      queryParameters: queryParameters,
    );
    return SuccessApiResponse.fromJson(
      responseData,
      (json) => _fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Reads a single resource item of type [T] by its unique [id].
  ///
  /// - [userId]: The unique identifier of the user performing the operation.
  ///   If `null`, the operation may be considered a global read, depending
  ///   on the resource type [T]. Implementations must handle the `null` case.
  /// - [id]: The unique identifier of the resource item to read.
  ///
  /// Sends a GET request to the item-specific API endpoint `[_basePath]/{id}`
  /// with the `model` query parameter set to [_modelName]. Includes the
  /// `userId` query parameter if provided.
  ///
  /// Example Request (user-scoped): `GET /api/v1/data/some-item-id?model=category&userId=user123`
  /// Example Request (global): `GET /api/v1/data/some-item-id?model=category`
  ///
  /// Returns a [SuccessApiResponse] containing the deserialized item.
  ///
  /// Throws [HtHttpException] or its subtypes (e.g., [NotFoundException]) on
  /// underlying HTTP communication failure. Exceptions during deserialization
  /// ([_fromJson]) will also propagate. These exceptions are intended to be
  /// handled by the caller.
  @override
  Future<SuccessApiResponse<T>> read({
    required String id,
    String? userId,
  }) async {
    // Exceptions from _httpClient or _fromJson are allowed to propagate.
    final queryParameters = <String, dynamic>{
      'model': _modelName,
      if (userId != null) 'userId': userId,
    };
    final responseData = await _httpClient.get<Map<String, dynamic>>(
      '$_basePath/$id',
      queryParameters: queryParameters,
    );
    return SuccessApiResponse.fromJson(
      responseData,
      (json) => _fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Reads all resource items of type [T], supporting pagination.
  ///
  /// - [userId]: The unique identifier of the user performing the operation.
  ///   If `null`, the operation should retrieve all *global* resources of type [T].
  ///   If provided, the operation should retrieve all resources scoped to that user.
  ///   Implementations must handle the `null` case.
  /// - [startAfterId]: Optional ID to start pagination after.
  /// - [limit]: Optional maximum number of items to return.
  ///
  /// Sends a GET request to the unified API endpoint `[_basePath]` with the
  /// `model` query parameter set to [_modelName]. Includes the `userId` query
  /// parameter if provided, and optional pagination parameters [startAfterId]
  /// and [limit].
  ///
  /// Example Request (user-scoped, first page): `GET /api/v1/data?model=source&userId=user123&limit=20`
  /// Example Request (global, next page): `GET /api/v1/data?model=source&startAfterId=last-source-id&limit=20`
  ///
  /// Returns a [SuccessApiResponse] containing a [PaginatedResponse] with the
  /// list of deserialized items and pagination details.
  ///
  /// Throws [HtHttpException] or its subtypes on underlying HTTP communication
  /// failure. Can also throw [FormatException] if the received data structure
  /// is incorrect (e.g., list item is not a Map) or other exceptions during
  /// deserialization ([_fromJson]). These exceptions are intended to be handled
  /// by the caller.
  @override
  Future<SuccessApiResponse<PaginatedResponse<T>>> readAll({
    String? userId,
    String? startAfterId,
    int? limit,
  }) async {
    // Exceptions from _httpClient are allowed to propagate.
    final queryParameters = <String, dynamic>{
      'model': _modelName,
      if (userId != null) 'userId': userId,
      if (startAfterId != null) 'startAfterId': startAfterId,
      if (limit != null) 'limit': limit,
    };
    final responseData = await _httpClient.get<Map<String, dynamic>>(
      _basePath,
      queryParameters: queryParameters,
    );

    return SuccessApiResponse.fromJson(
      responseData,
      (json) => PaginatedResponse.fromJson(
        json! as Map<String, dynamic>,
        (itemJson) {
          // Add type check for robustness against malformed API responses
          if (itemJson is Map<String, dynamic>) {
            return _fromJson(itemJson);
          } else {
            throw FormatException(
              'Expected Map<String, dynamic> in paginated list but got ${itemJson?.runtimeType}',
              itemJson,
            );
          }
        },
      ),
    );
  }

  /// Reads multiple resource items of type [T] based on a [query], supporting
  /// pagination.
  ///
  /// - [userId]: The unique identifier of the user performing the operation.
  ///   If `null`, the operation should retrieve *global* resources matching the
  ///   query. If provided, the operation should retrieve resources scoped to
  ///   that user matching the query. Implementations must handle the `null` case.
  /// - [query]: Map of query parameters to filter results.
  /// - [startAfterId]: Optional ID to start pagination after.
  /// - [limit]: Optional maximum number of items to return.
  ///
  /// Sends a GET request to the unified API endpoint `[_basePath]` with the
  /// `model` query parameter set to [_modelName], the provided [query] map,
  /// and optional pagination parameters ([startAfterId], [limit]). Includes
  /// the `userId` query parameter if provided.
  ///
  /// Example Request (user-scoped):
  /// `GET /api/v1/data?model=headline&userId=user123&category=tech&country=US&limit=10`
  /// Example Request (global):
  /// `GET /api/v1/data?model=headline&category=tech&country=US&limit=10`
  ///
  /// Returns a [SuccessApiResponse] containing a [PaginatedResponse] with the
  /// list of deserialized items matching the query and pagination details.
  ///
  /// Throws [HtHttpException] or its subtypes (e.g., [BadRequestException] for
  /// invalid query parameters) on underlying HTTP communication failure. Can
  /// also throw [FormatException] if the received data structure is incorrect
  /// or other exceptions during deserialization ([_fromJson]). These exceptions
  /// are intended to be handled by the caller.
  @override
  Future<SuccessApiResponse<PaginatedResponse<T>>> readAllByQuery(
    Map<String, dynamic> query, {
    String? userId,
    String? startAfterId,
    int? limit,
  }) async {
    // Exceptions from _httpClient are allowed to propagate.
    // Process the input query map for list-to-string conversion and 'query' to 'q' renaming
    final processedQueryInput = <String, dynamic>{};
    for (final entry in query.entries) {
      final key = entry.key == 'query' ? 'q' : entry.key;
      final value = entry.value;
      if (value is List) {
        processedQueryInput[key] = value.map((e) => e.toString()).join(',');
      } else {
        processedQueryInput[key] = value;
      }
    }

    final queryParameters = <String, dynamic>{
      'model': _modelName,
      if (userId != null) 'userId': userId,
      ...processedQueryInput,
      if (startAfterId != null) 'startAfterId': startAfterId,
      if (limit != null) 'limit': limit,
    };
    final responseData = await _httpClient.get<Map<String, dynamic>>(
      _basePath,
      queryParameters: queryParameters,
    );

    return SuccessApiResponse.fromJson(
      responseData,
      (json) => PaginatedResponse.fromJson(
        json! as Map<String, dynamic>,
        (itemJson) {
          // Add type check for robustness against malformed API responses
          if (itemJson is Map<String, dynamic>) {
            return _fromJson(itemJson);
          } else {
            throw FormatException(
              'Expected Map<String, dynamic> in paginated list but got ${itemJson?.runtimeType}',
              itemJson,
            );
          }
        },
      ),
    );
  }

  /// Updates an existing resource item of type [T] identified by [id].
  ///
  /// - [userId]: The unique identifier of the user performing the operation.
  ///   If `null`, the operation may be considered a global update (e.g.,
  ///   by an admin), depending on the resource type [T]. Implementations
  ///   must handle the `null` case appropriately.
  /// - [id]: The unique identifier of the resource item to update.
  /// - [item]: The updated resource item data.
  ///
  /// Sends a PUT request to the item-specific API endpoint `[_basePath]/{id}`
  /// with the serialized [item] data and the `model` query parameter set to
  /// [_modelName]. Includes the `userId` query parameter if provided.
  ///
  /// Example Request (user-scoped): `PUT /api/v1/data/some-item-id?model=category&userId=user123`
  /// Example Request (global): `PUT /api/v1/data/some-item-id?model=category`
  ///
  /// Returns a [SuccessApiResponse] containing the updated item as confirmed
  /// by the server.
  ///
  /// Throws [HtHttpException] or its subtypes (e.g., [NotFoundException]) on
  /// underlying HTTP communication failure. Exceptions during serialization
  /// ([_toJson]) or deserialization ([_fromJson]) will also propagate. These
  /// exceptions are intended to be handled by the caller.
  @override
  Future<SuccessApiResponse<T>> update({
    required String id,
    required T item,
    String? userId,
  }) async {
    // Exceptions from _httpClient or _fromJson/_toJson are allowed to propagate.
    final queryParameters = <String, dynamic>{
      'model': _modelName,
      if (userId != null) 'userId': userId,
    };
    final responseData = await _httpClient.put<Map<String, dynamic>>(
      '$_basePath/$id',
      data: _toJson(item),
      queryParameters: queryParameters,
    );
    return SuccessApiResponse.fromJson(
      responseData,
      (json) => _fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Deletes a resource item identified by [id].
  ///
  /// - [userId]: The unique identifier of the user performing the operation.
  ///   If `null`, the operation may be considered a global delete (e.g.,
  ///   by an admin), depending on the resource type [T]. Implementations
  ///   must handle the `null` case appropriately.
  /// - [id]: The unique identifier of the resource item to delete.
  ///
  /// Sends a DELETE request to the item-specific API endpoint `[_basePath]/{id}`
  /// with the `model` query parameter set to [_modelName]. Includes the
  /// `userId` query parameter if provided.
  /// Returns `void` upon successful deletion (typically indicated by a 204
  /// No Content response).
  ///
  /// Example Request (user-scoped): `DELETE /api/v1/data/some-item-id?model=source&userId=user123`
  /// Example Request (global): `DELETE /api/v1/data/some-item-id?model=source`
  ///
  /// Throws [HtHttpException] or its subtypes (e.g., [NotFoundException]) on
  /// underlying HTTP communication failure. These exceptions are intended to be
  /// handled by the caller.
  @override
  Future<void> delete({
    required String id,
    String? userId,
  }) async {
    // Exceptions from _httpClient are allowed to propagate.
    // We expect no content, but use <dynamic> for flexibility.
    final queryParameters = <String, dynamic>{
      'model': _modelName,
      if (userId != null) 'userId': userId,
    };
    await _httpClient.delete<dynamic>(
      '$_basePath/$id',
      queryParameters: queryParameters,
    );
  }
}
