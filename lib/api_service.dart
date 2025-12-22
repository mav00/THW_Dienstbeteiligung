import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';
import 'package:thw_dienstmanager/config.dart';

class ApiService {
  static Map<String, String> get _headers {
    String credentials = '${Config.username}:${Config.password}';
    String encoded = base64Encode(utf8.encode(credentials));
    return {
      'Authorization': 'Basic $encoded',
    };
  }

  static Future<dynamic> loadYamlData(String filename) async {
    try {
      final url = Uri.parse('${Config.baseUrl}/$filename');
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return loadYaml(response.body);
      }
    } catch (e) {
      print('Fehler beim Laden von $filename: $e');
    }
    return null;
  }

  static Future<void> saveYamlData(String filename, Object data) async {
    final url = Uri.parse('${Config.baseUrl}/$filename');
    
    final yamlWriter = YamlWriter();
    final yamlString = yamlWriter.write(data);
    
    try {
      await http.post(url, body: yamlString, headers: _headers);
    } catch (e) {
      print('Fehler beim Speichern von $filename: $e');
    }
  }
}