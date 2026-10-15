import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);
}

class ApiService {
  final http.Client _client;
  String? _token;
  ApiService({http.Client? client}) : _client = client ?? http.Client();
  void setToken(String? token) => _token = token;
  Future<dynamic> request(String method, String path, {Map<String, dynamic>? body}) async {
    final headers = {'Accept': 'application/json', 'Content-Type': 'application/json', if (_token != null) 'Authorization': 'Bearer $_token'};
    final url = Uri.parse('${ApiConfig.baseUrl}$path');
    try {
      final response = switch (method) { 'GET' => await _client.get(url, headers: headers), 'POST' => await _client.post(url, headers: headers, body: jsonEncode(body ?? {})), 'PUT' => await _client.put(url, headers: headers, body: jsonEncode(body ?? {})), 'PATCH' => await _client.patch(url, headers: headers, body: jsonEncode(body ?? {})), 'DELETE' => await _client.delete(url, headers: headers), _ => throw const ApiException('Método HTTP no soportado.') };
      final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
      if (response.statusCode >= 400) {
        var message = decoded is Map ? (decoded['message']?.toString() ?? 'Solicitud rechazada.') : 'Solicitud rechazada.';
        if (decoded is Map && decoded['errors'] is Map) message = (decoded['errors'] as Map).values.expand((e) => e as List).join('\n');
        throw ApiException(message, response.statusCode);
      }
      return decoded;
    } on TimeoutException { throw const ApiException('La solicitud tardó demasiado.'); }
    on http.ClientException { throw const ApiException('No se pudo conectar con Laravel.'); }
    on FormatException { throw const ApiException('La API no devolvió JSON válido.'); }
  }
  Future<dynamic> get(String path) => request('GET', path);
  Future<dynamic> post(String path, Map<String, dynamic> body) => request('POST', path, body: body);
  Future<dynamic> put(String path, Map<String, dynamic> body) => request('PUT', path, body: body);
  Future<dynamic> patch(String path, Map<String, dynamic> body) => request('PATCH', path, body: body);
  Future<dynamic> delete(String path) => request('DELETE', path);
  void dispose() => _client.close();
}
