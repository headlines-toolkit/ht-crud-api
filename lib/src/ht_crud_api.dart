import 'package:ht_crud_client/ht_crud_client.dart';
import 'package:ht_http_client/ht_http_client.dart';

/// {@template ht_crud_client}
/// Defines the interface for a generic client performing standard CRUD
/// (Create, Read, Update, Delete) operations for a resource type [T].
///
/// Implementations of this interface are expected to handle the underlying
/// communication (e.g., HTTP requests) and manage serialization/deserialization
/// via provided [FromJson] and [ToJson] functions if necessary.
///
/// This implementation relies on an injected [HtHttpClient] for the actual HTTP
/// communication. It requires the base path for the resource endpoint
/// (e.g., '/users', '/products') and functions to serialize ([ToJson])
/// and deserialize ([FromJson]) the generic type [T].
/// {@endtemplate}
class CrudApi<T> implements HtCrudClient<T> {
  /// {@macro ht_crud_client}
  const CrudApi({
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
  Future<T> create(T item) async {
    // Exceptions from _httpClient or _fromJson/_toJson are allowed to propagate.
    final responseData = await _httpClient.post<Map<String, dynamic>>(
      _endpointPath,
      data: _toJson(item),
    );
    return _fromJson(responseData);
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
  Future<T> read(String id) async {
    // Exceptions from _httpClient or _fromJson are allowed to propagate.
    final responseData = await _httpClient.get<Map<String, dynamic>>(
      '$_endpointPath/$id',
    );
    return _fromJson(responseData);
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
  Future<List<T>> readAll() async {
    // Exceptions from _httpClient are allowed to propagate.
    final responseData = await _httpClient.get<List<dynamic>>(
      _endpointPath,
    );

    try {
      // Map response list, allowing _fromJson errors to propagate.
      // Catch FormatException specifically if item type is wrong.
      return responseData.map((item) {
        if (item is Map<String, dynamic>) {
          return _fromJson(item);
        } else {
          throw FormatException(
            'Expected Map<String, dynamic> in list but got ${item.runtimeType}',
            item,
          );
        }
      }).toList();
    } on FormatException {
      // Allow FormatException from mapping logic to propagate.
      rethrow;
    }
    // Other potential exceptions from _fromJson within the map will
    // also propagate.
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
  Future<T> update(String id, T item) async {
    // Exceptions from _httpClient or _fromJson/_toJson are allowed to propagate.
    final responseData = await _httpClient.put<Map<String, dynamic>>(
      '$_endpointPath/$id',
      data: _toJson(item),
    );
    return _fromJson(responseData);
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
    await _httpClient.delete<dynamic>(
      '$_endpointPath/$id',
    );
  }
}
