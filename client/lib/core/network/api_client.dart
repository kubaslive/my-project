import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiClient {
  final String baseUrl;

  ApiClient({this.baseUrl = 'http://localhost:8080'});

  /// Pobiera listę jednostek ZRM
  Future<List<ZRMUnit>> getUnits() async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/units'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => ZRMUnit.fromJson(json)).toList();
    }
    throw Exception('Błąd pobierania karetek: ${response.statusCode}');
  }

  /// Pobiera listę zleceń wyjazdu (KZW)
  Future<List<Dispatch>> getDispatches() async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/dispatches'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Dispatch.fromJson(json)).toList();
    }
    throw Exception('Błąd pobierania zleceń: ${response.statusCode}');
  }

  /// Tworzy nowe zlecenie wyjazdu (KZW)
  Future<Dispatch> createDispatch(Dispatch dispatch) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/dispatches'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dispatch.toJson()),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return Dispatch.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }
    throw Exception('Błąd tworzenia zlecenia: ${response.body}');
  }

  /// Pobiera kartę medyczną KMCR
  Future<KMCR?> getKMCR(String dispatchId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/kmcr/$dispatchId'));
    if (response.statusCode == 200) {
      return KMCR.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }
    return null;
  }

  /// Zapisuje kartę medyczną KMCR
  Future<KMCR> saveKMCR(KMCR kmcr) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/kmcr'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(kmcr.toJson()),
    );
    if (response.statusCode == 200) {
      return KMCR.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    }
    throw Exception('Błąd zapisu karty medycznej: ${response.body}');
  }
}
