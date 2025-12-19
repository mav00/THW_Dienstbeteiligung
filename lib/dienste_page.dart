import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';
import 'package:intl/intl.dart';
import 'package:thw_dienstmanager/dienst.dart';
import 'package:thw_dienstmanager/person.dart';

class DienstePage extends StatefulWidget {
  @override
  _DienstePageState createState() => _DienstePageState();
}

class _DienstePageState extends State<DienstePage> {
  List<Dienst> _dienste = [];
  bool _isLoading = true;
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');

  @override
  void initState() {
    super.initState();
    ladeDienste();
  }

  Future<void> ladeDienste() async {
    List<Dienst> geladeneDienste = [];
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/dienste.yaml');
      if (await file.exists()) {
        final yamlString = await file.readAsString();
        final yamlList = loadYaml(yamlString) as YamlList;
        geladeneDienste = yamlList.map((e) => Dienst.fromMap(Map<String, dynamic>.from(e))).toList();
        // Sortiere nach Datum absteigend (neueste zuerst)
        geladeneDienste.sort((a, b) => b.datum.compareTo(a.datum));
      }
    } catch (e) {
      print('Fehler beim Laden der Dienste: $e');
    }

    if (mounted) {
      setState(() {
        _dienste = geladeneDienste;
        _isLoading = false;
      });
    }
  }

  Future<void> speichereDienste() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/dienste.yaml');
    
    final yamlWriter = YamlWriter();
    final yamlString = yamlWriter.write(_dienste.map((d) => d.toMap()).toList());
    
    await file.writeAsString(yamlString);
  }

  void _bearbeiteOderErstelleDienst({Dienst? dienst, int? index}) {
    DateTime ausgewaehltesDatum = dienst?.datum ?? DateTime.now();
    List<Einheit> ausgewaehlteEinheiten = dienst != null ? List.from(dienst.einheiten) : [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(dienst == null ? 'Neuen Dienst anlegen' : 'Dienst bearbeiten'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text('Datum: ${_dateFormat.format(ausgewaehltesDatum)}'),
                        Spacer(),
                        Ink(
                          decoration: const ShapeDecoration(
                            color: Color(0xFF003399),
                            shape: CircleBorder(),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            color: Colors.white,
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: ausgewaehltesDatum,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  ausgewaehltesDatum = picked;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text('Beteiligte Einheiten:'),
                    Wrap(
                      spacing: 8.0,
                      children: Einheit.values.map((e) {
                        final isSelected = ausgewaehlteEinheiten.contains(e);
                        return FilterChip(
                          label: Text(e.toString().split('.').last),
                          selected: isSelected,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                ausgewaehlteEinheiten.add(e);
                              } else {
                                ausgewaehlteEinheiten.remove(e);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Abbrechen')),
                ElevatedButton(
                  onPressed: () {
                    final neuerDienst = Dienst(ausgewaehltesDatum, ausgewaehlteEinheiten);
                    setState(() {
                      if (index != null) {
                        _dienste[index!] = neuerDienst;
                      } else {
                        _dienste.add(neuerDienst);
                      }
                      _dienste.sort((a, b) => b.datum.compareTo(a.datum));
                    });
                    speichereDienste();
                    Navigator.pop(context);
                  },
                  child: Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _loescheDienst(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dienst löschen'),
        content: Text('Möchten Sie den Dienst am ${_dateFormat.format(_dienste[index].datum)} wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Abbrechen')),
          TextButton(
            onPressed: () {
              setState(() {
                _dienste.removeAt(index);
              });
              speichereDienste();
              Navigator.pop(context);
            },
            child: Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('Neuen Dienst hinzufügen'),
                onPressed: () => _bearbeiteOderErstelleDienst(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF003399),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _dienste.isEmpty
                    ? Center(child: Text('Keine Dienste gefunden'))
                    : ListView.builder(
                        itemCount: _dienste.length,
                        itemBuilder: (context, index) {
                          final dienst = _dienste[index];
                          return ListTile(
                            title: Text(_dateFormat.format(dienst.datum)),
                            subtitle: Text(
                                'Einheiten: ${dienst.einheiten.map((e) => e.toString().split('.').last).join(', ')}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Ink(
                                  decoration: const ShapeDecoration(
                                    color: Color(0xFF003399),
                                    shape: CircleBorder(),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.edit),
                                    color: Colors.white,
                                    onPressed: () => _bearbeiteOderErstelleDienst(dienst: dienst, index: index),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Ink(
                                  decoration: const ShapeDecoration(
                                    color: Color(0xFF003399),
                                    shape: CircleBorder(),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: Colors.white,
                                    onPressed: () => _loescheDienst(index),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
    );
  }
}