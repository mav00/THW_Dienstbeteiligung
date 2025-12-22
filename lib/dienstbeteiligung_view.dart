import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:thw_dienstmanager/dienst.dart';
import 'package:thw_dienstmanager/person.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';
import 'package:thw_dienstmanager/dienst_status.dart';
import 'package:thw_dienstmanager/pdf_export_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:thw_dienstmanager/config.dart';

class DienstbeteiligungView extends StatefulWidget {
  final List<Dienst> dienste;
  final Future<List<Person>> personenFuture;

  const DienstbeteiligungView({
    Key? key,
    required this.dienste,
    required this.personenFuture,
  }) : super(key: key);

  @override
  _DienstbeteiligungViewState createState() => _DienstbeteiligungViewState();
}

class _DienstbeteiligungViewState extends State<DienstbeteiligungView> {
  Dienst? _ausgewaehlterDienst;
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');
  final Map<Dienst, Map<Person, DienstStatus>> _anwesenheitsListe = {};

  int _getFunktionSortValue(List<Funktion> funktionen) {
    const funktionOrder = {
      Funktion.ZFue: 0,
      Funktion.ZTrFue: 1,
      Funktion.GrFue: 2,
      Funktion.TrFue: 3,
      Funktion.KF: 4,
    };

    int bestValue = 5; // Standardwert für keine der priorisierten Funktionen
    if (funktionen.isEmpty) return bestValue;

    for (var f in funktionen) {
      if (funktionOrder.containsKey(f) && funktionOrder[f]! < bestValue) {
        bestValue = funktionOrder[f]!;
      }
    }
    return bestValue;
  }

  @override
  void initState() {
    super.initState();
    _updateSelection();
    _loadAttendance();
  }

  @override
  void didUpdateWidget(DienstbeteiligungView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dienste != oldWidget.dienste) {
      _updateSelection();
    }
  }

  Future<void> _loadAttendance() async {
    try {
      final url = Uri.parse('${Config.baseUrl}/anwesenheit.yaml');
      final response = await http.get(url);
      
      if (response.statusCode != 200 || response.body.isEmpty) return;
      final content = response.body;
      
      final yamlList = loadYaml(content);
      if (yamlList == null) return;

      final personen = await widget.personenFuture;
      final Map<Dienst, Map<Person, DienstStatus>> loadedData = {};

      for (var entry in yamlList) {
        final dateStr = entry['date'];
        // Dienst anhand des Datums finden
        Dienst? dienst;
        try {
          dienst = widget.dienste.firstWhere(
            (d) => _dateFormat.format(d.datum) == dateStr
          );
        } catch (e) {
          continue; // Dienst existiert nicht mehr
        }

        final attendanceList = entry['attendance'] as List;
        final Map<Person, DienstStatus> statusMap = {};

        for (var att in attendanceList) {
          final personMap = Map<String, dynamic>.from(att['person']);
          final statusStr = att['status'];
          
          // Person finden (Vergleich über Map-Daten, um Objekt-Identität zu wahren)
          Person person;
          try {
            person = personen.firstWhere((p) {
              final pMap = p.toMap();
              if (pMap.length != personMap.length) return false;
              for (var key in pMap.keys) {
                if (pMap[key].toString() != personMap[key].toString()) return false;
              }
              return true;
            });
          } catch (e) {
            // Person nicht gefunden (evtl. gelöscht), aus gespeicherten Daten wiederherstellen
            person = Person.fromMap(personMap);
          }
          statusMap[person] = DienstStatus.values.firstWhere((e) => e.name == statusStr);
        }
        
        if (statusMap.isNotEmpty) {
          loadedData[dienst] = statusMap;
        }
      }

      if (mounted) {
        setState(() {
          _anwesenheitsListe.addAll(loadedData);
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Anwesenheit: $e');
    }
  }

  Future<void> _saveAttendance() async {
    final url = Uri.parse('${Config.baseUrl}/anwesenheit.yaml');
    
    final List<Map<String, dynamic>> exportList = [];
    
    _anwesenheitsListe.forEach((dienst, personStatusMap) {
      if (personStatusMap.isEmpty) return;
      
      final String dateStr = _dateFormat.format(dienst.datum);
      final List<Map<String, dynamic>> attendanceList = [];
      
      personStatusMap.forEach((person, status) {
        attendanceList.add({
          'person': person.toMap(),
          'status': status.name,
        });
      });
      
      exportList.add({
        'date': dateStr,
        'attendance': attendanceList,
      });
    });

    final yamlWriter = YamlWriter();
    final yamlString = yamlWriter.write(exportList);
    try {
      await http.post(url, body: yamlString);
    } catch (e) {
      print('Fehler beim Speichern der Anwesenheit: $e');
    }
  }

  Future<void> _exportPdf() async {
    if (_ausgewaehlterDienst == null) return;

    final service = PdfExportService();
    final personen = await widget.personenFuture;
    final statusMap = _anwesenheitsListe[_ausgewaehlterDienst] ?? {};

    final file = await service.exportSingleServicePdf(_ausgewaehlterDienst!, personen, statusMap);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF gespeichert unter: ${file.path}')),
      );
      await OpenFilex.open(file.path);
    }
  }

  Future<void> _exportYearlyPdf() async {
    final service = PdfExportService();
    final personen = await widget.personenFuture;
    final currentYear = DateTime.now().year;

    final file = await service.exportYearlyPdf(currentYear, widget.dienste, personen, _anwesenheitsListe);

    if (mounted) {
      if (file != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Jahresübersicht gespeichert: ${file.path}')),
        );
        await OpenFilex.open(file.path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Dienste im aktuellen Jahr gefunden.')),
        );
      }
    }
  }

  void _updateSelection() {
    if (_ausgewaehlterDienst != null && !widget.dienste.contains(_ausgewaehlterDienst)) {
      _ausgewaehlterDienst = null;
    }
    if (_ausgewaehlterDienst == null && widget.dienste.isNotEmpty) {
      _ausgewaehlterDienst = widget.dienste.first;
    }
    if (widget.dienste.isEmpty) {
      _ausgewaehlterDienst = null;
    }
  }

  int _getAnwesendeCount() {
    if (_ausgewaehlterDienst == null) return 0;
    final statusMap = _anwesenheitsListe[_ausgewaehlterDienst];
    if (statusMap == null) return 0;
    return statusMap.values.where((status) => status == DienstStatus.x).length;
  }

  int _getAnwesendeKFCount() {
    if (_ausgewaehlterDienst == null) return 0;
    final statusMap = _anwesenheitsListe[_ausgewaehlterDienst];
    if (statusMap == null) return 0;
    return statusMap.entries.where((entry) => 
      entry.value == DienstStatus.x && entry.key.funktionen.contains(Funktion.KF)
    ).length;
  }

  Widget _buildStatusButton(Person person, DienstStatus status, String text, Color color) {
    final isSelected = _anwesenheitsListe[_ausgewaehlterDienst]?[person] == status;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          if (_ausgewaehlterDienst != null) {
            if (!_anwesenheitsListe.containsKey(_ausgewaehlterDienst!)) {
              _anwesenheitsListe[_ausgewaehlterDienst!] = {};
            }
            if (_anwesenheitsListe[_ausgewaehlterDienst!]![person] == status) {
              _anwesenheitsListe[_ausgewaehlterDienst!]!.remove(person);
            } else {
              _anwesenheitsListe[_ausgewaehlterDienst!]![person] = status;
            }
            _saveAttendance();
          }
        });
      },
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(12),
        backgroundColor: isSelected ? color : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black,
        minimumSize: const Size(40, 40),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dienste.isEmpty) {
      return Center(child: Text('Keine Dienste vorhanden.'));
    }

    return FutureBuilder<List<Person>>(
      future: widget.personenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Fehler: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('Keine Personen gefunden'));
        } else {
          final allePersonen = snapshot.data!;
          List<Person> teilnehmendePersonen = [];

          if (_ausgewaehlterDienst != null) {
            final Set<Person> uniquePersons = {};
            // 1. Aktive Personen der Einheit hinzufügen
            uniquePersons.addAll(allePersonen.where((p) => _ausgewaehlterDienst!.einheiten.contains(p.einheit)));
            
            // 2. Personen aus der Anwesenheitsliste hinzufügen (inkl. gelöschter)
            if (_anwesenheitsListe.containsKey(_ausgewaehlterDienst)) {
              uniquePersons.addAll(_anwesenheitsListe[_ausgewaehlterDienst]!.keys);
            }
            
            teilnehmendePersonen = uniquePersons.toList();
            // Sortieren nach den Regeln: 1. Einheit, 2. Funktion, 3. Name
            teilnehmendePersonen.sort((a, b) {
              // 1. Nach Einheit (ZTr, B, N, E)
              int einheitCompare = a.einheit.index.compareTo(b.einheit.index);
              if (einheitCompare != 0) return einheitCompare;

              // 2. Nach Funktion (ZFue, ZTrFue, GrFue, TrFue, KF)
              int funktionAValue = _getFunktionSortValue(a.funktionen);
              int funktionBValue = _getFunktionSortValue(b.funktionen);
              int funktionCompare = funktionAValue.compareTo(funktionBValue);
              if (funktionCompare != 0) return funktionCompare;

              // 3. Nach Name
              int nameCompare = a.name.compareTo(b.name);
              return nameCompare != 0 ? nameCompare : a.vorname.compareTo(b.vorname);
            });
          }

          return Column(
            children: [
              DropdownButtonFormField<Dienst>(
                value: _ausgewaehlterDienst,
                dropdownColor: Colors.white,
                decoration: InputDecoration(labelText: "Dienst auswählen"),
                isExpanded: true,
                items: widget.dienste.map((dienst) {
                  final dateStr = _dateFormat.format(dienst.datum);
                  final unitsStr = dienst.einheiten.map((e) => e.toString().split('.').last).join(', ');
                  return DropdownMenuItem<Dienst>(
                    value: dienst,
                    child: Text('$dateStr ($unitsStr)'),
                  );
                }).toList(),
                onChanged: (Dienst? neuerDienst) {
                  setState(() {
                    _ausgewaehlterDienst = neuerDienst;
                  });
                },
              ),
              Expanded(
                child: teilnehmendePersonen.isEmpty
                    ? Center(child: Text('Keine Teilnehmer für diesen Dienst.'))
                    : ListView.builder(
                        itemCount: teilnehmendePersonen.length,
                        itemBuilder: (context, index) {
                          final person = teilnehmendePersonen[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          person.getRichTextName(),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Funktionen: ${person.funktionen.map((f) => f.toString().split('.').last).join(', ')}',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildStatusButton(person, DienstStatus.x, 'x', Colors.green),
                                          const SizedBox(width: 8),
                                          _buildStatusButton(person, DienstStatus.b, 'b', Colors.yellow),
                                          const SizedBox(width: 8),
                                          _buildStatusButton(person, DienstStatus.k, 'k', Colors.yellow),
                                          const SizedBox(width: 8),
                                          _buildStatusButton(person, DienstStatus.u, 'u', Colors.red),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                            ],
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.grey[200],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Anwesende Helfer (x):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${_getAnwesendeCount()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Anwesende Kraftfahrer (KF):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${_getAnwesendeKFCount()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Als PDF exportieren'),
                        onPressed: _exportPdf,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003399),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Jahresübersicht (PDF)'),
                        onPressed: _exportYearlyPdf,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003399),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      },
    );
  }
}