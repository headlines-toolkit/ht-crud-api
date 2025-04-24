//
// ignore_for_file: avoid_print, lines_longer_than_80_chars

import 'package:ht_http_client/ht_http_client.dart';

/// A function that converts a JSON map to an object of type [T].
typedef FromJson<T> = T Function(Map<String, dynamic> json);

/// A function that converts an object of type [T] to a JSON map.
typedef ToJson<T> = Map<String, dynamic> Function(T item);

/// {@template crud_api}
/// A generic client for performing standard CRUD (Create, Read, Update, Delete)
/// operations against a RESTful API endpoint for a specific resource type [T].
///
/// This class relies on an injected [HtHttpClient] for the actual HTTP
/// communication. It explicitly catches and re-throws [HtHttpException]s
/// originating from the HTTP client. It requires the base path for the
/// resource endpoint (e.g., '/users', '/products') and functions to serialize
/// and deserialize the generic type [T].
/// {@endtemplate}
class CrudApi<T> {
  /// {@macro crud_api}
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
  /// Sends a POST request to the base [_endpointPath] with the serialized
  /// [item].
  /// Returns the created item, typically including server-assigned fields
  /// like an ID.
  ///
  /// Catches and re-throws [HtHttpException] if the underlying request fails.
  Future<T> create(T item) async {
    try {
      final responseData = await _httpClient.post<Map<String, dynamic>>(
        _endpointPath,
        data: _toJson(item),
      );
      return _fromJson(responseData);
    } on HtHttpException {
      // Re-throw the specific HTTP exception from the client
      rethrow;
    } catch (e) {
      // Catch any other unexpected errors during the process
      // (e.g., serialization/deserialization issues, though less likely here)
      // Consider logging this or wrapping it in a custom domain exception
      // For now, rethrowing to make the caller aware.
      // Depending on policy, might wrap in an UnknownException or similar.
      print('Unexpected error during create: $e'); // Basic logging
      rethrow; // Or throw custom exception
    }
  }

  /// Reads a single resource item of type [T] by its [id].
  ///
  /// Sends a GET request to `[_endpointPath]/{id}`.
  /// Returns the deserialized item.
  ///
  /// Catches and re-throws [HtHttpException] (e.g., [NotFoundException])
  /// if the underlying request fails or the item doesn't exist.
  Future<T> read(String id) async {
    try {
      final responseData = await _httpClient.get<Map<String, dynamic>>(
        '$_endpointPath/$id',
      );
      return _fromJson(responseData);
    } on HtHttpException {
      rethrow;
    } catch (e) {
      print('Unexpected error during read: $e');
      rethrow;
    }
  }

  /// Reads all resource items of type [T].
  ///
  /// Sends a GET request to the base [_endpointPath].
  /// Expects a JSON array in the response.
  /// Returns a list of deserialized items.
  ///
  /// Catches and re-throws [HtHttpException] if the underlying request fails.
  /// Also catches potential [FormatException] during list item processing.
  Future<List<T>> readAll() async {
    try {
      final responseData = await _httpClient.get<List<dynamic>>(
        _endpointPath,
      );

      return responseData.map((item) {
        if (item is Map<String, dynamic>) {
          return _fromJson(item);
        } else {
          // Throw a specific error if item type is wrong
          throw FormatException(
            'Expected a Map<String, dynamic> in list but got ${item.runtimeType}',
          );
        }
      }).toList();
    } on HtHttpException {
      rethrow;
    } on FormatException {
      // Re-throw format exceptions from the mapping logic
      rethrow;
    } catch (e) {
      print('Unexpected error during readAll: $e');
      rethrow;
    }
  }

  /// Updates an existing resource item of type [T] identified by [id].
  ///
  /// Sends a PUT request to `[_endpointPath]/{id}` with the serialized [item].
  /// Returns the updated item as returned by the server.
  ///
  /// Catches and re-throws [HtHttpException] if the underlying request fails.
  Future<T> update(String id, T item) async {
    try {
      final responseData = await _httpClient.put<Map<String, dynamic>>(
        '$_endpointPath/$id',
        data: _toJson(item),
      );
      return _fromJson(responseData);
    } on HtHttpException {
      rethrow;
    } catch (e) {
      print('Unexpected error during update: $e');
      rethrow;
    }
  }

  /// Deletes a resource item identified by [id].
  ///
  /// Sends a DELETE request to `[_endpointPath]/{id}`.
  /// Returns `void`.
  ///
  /// Catches and re-throws [HtHttpException] if the underlying request fails.
  Future<void> delete(String id) async {
    try {
      await _httpClient.delete<dynamic>(
        '$_endpointPath/$id',
      );
    } on HtHttpException {
      rethrow;
    } catch (e) {
      print('Unexpected error during delete: $e');
      rethrow;
    }
  }
}
