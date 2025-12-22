import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:thw_dienstmanager/person.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';
import 'package:thw_dienstmanager/eintrag_abwesenheit.dart';
import 'package:thw_dienstmanager/helferdaten_page.dart';
import 'package:thw_dienstmanager/abwesenheiten_ansehen_view.dart';
import 'package:thw_dienstmanager/dienste_page.dart';
import 'package:thw_dienstmanager/dienst.dart';
import 'package:thw_dienstmanager/dienstbeteiligung_view.dart';
import 'package:thw_dienstmanager/config.dart';

enum Ansicht { eintraegeAnsehen, dienstbeteiligung, diensteVerwalten, helferDaten }

Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<File> get _localFile async {
  final path = await _localPath;
  return File('$path/abwesenheiten.yaml');
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Ansicht _auswahl = Ansicht.eintraegeAnsehen;

  DateTime? _filterDatum;

  List<EintragAbwesenheit> _eintraege = [];

  List<Dienst> _dienste = [];

  late Future<List<Person>> _personenFuture;

  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');

  Future<List<Person>> ladePersonenAusYaml() async {
    try {
      final url = Uri.parse('${Config.baseUrl}/persons.yaml');
      final response = await http.get(url);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final yamlString = response.body;
        final yamlList = loadYaml(yamlString) as YamlList;
        return yamlList.map((e) => Person.fromMap(Map<String, dynamic>.from(e))).toList();
      }
    } catch (e) {
      print('Fehler beim Laden der lokalen Personen: $e');
    }

    return [];
  }

  Future<void> speichereEintraegeInYaml() async {
    final url = Uri.parse('${Config.baseUrl}/abwesenheiten.yaml');
    final eintraegeMapList = _eintraege.map((eintrag) => {
      'person': eintrag.person.toMap(),
      'von': _dateFormat.format(eintrag.von),
      'bis': _dateFormat.format(eintrag.bis),
    }).toList();

    final yamlWriter = YamlWriter();
    final yamlString = yamlWriter.write(eintraegeMapList);
    
    try {
      await http.post(url, body: yamlString);
    } catch (e) {
      print('Fehler beim Speichern der Abwesenheiten: $e');
    }
  }

  Future<void> ladeEintraegeAusYaml() async {
    try {
      final url = Uri.parse('${Config.baseUrl}/abwesenheiten.yaml');
      final response = await http.get(url);
      
      if (response.statusCode != 200 || response.body.isEmpty) return;

      final yamlList = loadYaml(response.body);
      if (yamlList == null) return;

      List<EintragAbwesenheit> geladene = [];
      for (var element in yamlList) {
        final map = Map<String, dynamic>.from(element);
        final person = Person.fromMap(Map<String, dynamic>.from(map['person']));
        geladene.add(EintragAbwesenheit(
            person, _dateFormat.parse(map['von']), _dateFormat.parse(map['bis'])));
      }
      setState(() {
        _eintraege = geladene;
      });
    } catch (e) {
      print('Fehler beim Laden der Einträge: $e');
    }
  }

  Future<void> ladeDiensteAusYaml() async {
    try {
      final url = Uri.parse('${Config.baseUrl}/dienste.yaml');
      final response = await http.get(url);
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final yamlString = response.body;
        final yamlList = loadYaml(yamlString) as YamlList;
        List<Dienst> geladene = yamlList.map((e) => Dienst.fromMap(Map<String, dynamic>.from(e))).toList();
        geladene.sort((a, b) => b.datum.compareTo(a.datum));
        
        setState(() {
          _dienste = geladene;
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Dienste: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _filterDatum = DateTime.now();
    _filterDatum = DateTime(_filterDatum!.year, _filterDatum!.month, _filterDatum!.day);
    _personenFuture = ladePersonenAusYaml();
    ladeEintraegeAusYaml();
    ladeDiensteAusYaml();
  }

  void _showNeuerEintragDialog() {
    DateTime? datumVon;
    DateTime? datumBis;
    Person? ausgewaehltePerson;
    final datumVonController = TextEditingController();
    final datumBisController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Neue Abwesenheit'),
              content: SizedBox(
                width: double.maxFinite,
                child: FutureBuilder<List<Person>>(
                  future: _personenFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Text('Fehler: ${snapshot.error}');
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('Keine Personen gefunden');
                    } else {
                      final personen = snapshot.data!;
                      if (ausgewaehltePerson == null && personen.isNotEmpty) {
                        ausgewaehltePerson = personen.first;
                      }
                      if (ausgewaehltePerson != null && !personen.contains(ausgewaehltePerson)) {
                         try {
                           ausgewaehltePerson = personen.firstWhere((p) => p.toMap().toString() == ausgewaehltePerson!.toMap().toString());
                         } catch (e) {
                           ausgewaehltePerson = personen.first;
                         }
                      }

                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField<Person>(
                              value: ausgewaehltePerson,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: "Person auswählen"),
                              items: personen.map((person) {
                                return DropdownMenuItem<Person>(
                                  value: person,
                                  child: person.getRichTextName(),
                                );
                              }).toList(),
                              onChanged: (Person? neuePerson) {
                                setDialogState(() {
                                  ausgewaehltePerson = neuePerson;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: datumVonController,
                                    decoration: const InputDecoration(labelText: "Datum von", hintText: 'TT.MM.JJJJ'),
                                    keyboardType: TextInputType.datetime,
                                    onChanged: (value) {
                                       try {
                                          final parsed = _dateFormat.parseStrict(value);
                                          setDialogState(() => datumVon = parsed);
                                       } catch (_) {}
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.calendar_today, color: Color(0xFF003399)),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: datumVon ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        datumVon = picked;
                                        datumVonController.text = _dateFormat.format(picked);
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: datumBisController,
                                    decoration: const InputDecoration(labelText: "Datum bis", hintText: 'TT.MM.JJJJ'),
                                    keyboardType: TextInputType.datetime,
                                    onChanged: (value) {
                                       try {
                                          final parsed = _dateFormat.parseStrict(value);
                                          setDialogState(() => datumBis = parsed);
                                       } catch (_) {}
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.calendar_today, color: Color(0xFF003399)),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: datumBis ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        datumBis = picked;
                                        datumBisController.text = _dateFormat.format(picked);
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (ausgewaehltePerson == null || datumVon == null || datumBis == null) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte alle Felder ausfüllen')));
                       return;
                    }
                    if (datumVon!.isAfter(datumBis!)) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datum von darf nicht nach Datum bis sein')));
                        return;
                    }
                    setState(() {
                      _eintraege.add(EintragAbwesenheit(ausgewaehltePerson!, datumVon!, datumBis!));
                    });
                    speichereEintraegeInYaml();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003399),
                      foregroundColor: Colors.white,
                  ),
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF003399),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      'assets/logo.jpg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'THW Dienstmanager',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Abwesenheiten'),
            selected: _auswahl == Ansicht.eintraegeAnsehen,
            onTap: () {
              setState(() {
                _auswahl = Ansicht.eintraegeAnsehen;
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment_ind),
            title: const Text('Dienstbeteiligung'),
            selected: _auswahl == Ansicht.dienstbeteiligung,
            onTap: () {
              setState(() {
                _auswahl = Ansicht.dienstbeteiligung;
              });
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Dienste verwalten'),
            selected: _auswahl == Ansicht.diensteVerwalten,
            onTap: () {
              setState(() {
                _auswahl = Ansicht.diensteVerwalten;
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Helferdaten'),
            selected: _auswahl == Ansicht.helferDaten,
            onTap: () {
              setState(() {
                _auswahl = Ansicht.helferDaten;
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  AppBar getAppBar() {
    String title = 'Abwesenheiten 1.TZ';
    switch (_auswahl) {
      case Ansicht.eintraegeAnsehen:
        title = 'Abwesenheiten';
        break;
      case Ansicht.dienstbeteiligung:
        title = 'Dienstbeteiligung';
        break;
      case Ansicht.diensteVerwalten:
        title = 'Dienste verwalten';
        break;
      case Ansicht.helferDaten:
        title = 'Helferdaten';
        break;
    }
    return AppBar(
      backgroundColor: Color(0xFF003399),
      foregroundColor: Colors.white,
      centerTitle: true,
      title: Text(title),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/thw.png'),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: getAppBar(),
      drawer: _buildDrawer(),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_auswahl) {
      case Ansicht.eintraegeAnsehen:
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Neue Abwesenheit hinzufügen'),
                  onPressed: () => _showNeuerEintragDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003399),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            Expanded(
              child: AbwesenheitenAnsehenView(
                eintraege: _eintraege,
                filterDatum: _filterDatum,
                onFilterDatumChanged: (datum) {
                  setState(() => _filterDatum = datum);
                },
                onEintragRemoved: (eintrag) async {
                  setState(() {
                    _eintraege.remove(eintrag);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Eintrag gelöscht')),
                  );
                  await speichereEintraegeInYaml();
                },
              ),
            ),
          ],
        );
      case Ansicht.dienstbeteiligung:
        // Daten neu laden, falls sie in der Verwaltung geändert wurden
        ladeDiensteAusYaml();
        return DienstbeteiligungView(
          dienste: _dienste,
          personenFuture: _personenFuture,
        );
      case Ansicht.diensteVerwalten:
        return DienstePage();
      case Ansicht.helferDaten:
        // Personen neu laden, falls sie geändert wurden
        _personenFuture = ladePersonenAusYaml();
        return HelferdatenPage();
    }
  }
}