import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:thw_urlaub/person.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';
import 'package:thw_urlaub/eintrag_abwesenheit.dart';
import 'package:thw_urlaub/helferdaten_page.dart';
import 'package:thw_urlaub/abwesenheiten_ansehen_view.dart';
import 'package:thw_urlaub/dienste_page.dart';
import 'package:thw_urlaub/dienst.dart';
import 'package:thw_urlaub/dienstbeteiligung_view.dart';

enum Ansicht { eintraegeAnsehen, neuerEintrag, dienstbeteiligung, diensteVerwalten, helferDaten }

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
  Ansicht _auswahl = Ansicht.neuerEintrag;

  final _datumVonController = TextEditingController();
  DateTime? _datumVon;

  final _datumBisController = TextEditingController();
  DateTime? _datumBis;

  DateTime? _filterDatum;

  List<EintragAbwesenheit> _eintraege = [];

  List<Dienst> _dienste = [];

  late Future<List<Person>> _personenFuture;

  Person? _ausgewaehltePerson;

  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');

  Future<List<Person>> ladePersonenAusYaml() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/persons.yaml');
      if (await file.exists()) {
        final yamlString = await file.readAsString();
        final yamlList = loadYaml(yamlString) as YamlList;
        return yamlList.map((e) => Person.fromMap(Map<String, dynamic>.from(e))).toList();
      }
    } catch (e) {
      print('Fehler beim Laden der lokalen Personen: $e');
    }

    final yamlString = await rootBundle.loadString('assets/persons.yaml');
    final yamlList = loadYaml(yamlString) as YamlList;

    List<Person> personen = yamlList
        .map((e) => Person.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    return personen;
  }

  Future<void> speichereEintraegeInYaml() async {
    final file = await _localFile;

    final eintraegeMapList = _eintraege.map((eintrag) => {
      'person': eintrag.person.toMap(),
      'von': _dateFormat.format(eintrag.von),
      'bis': _dateFormat.format(eintrag.bis),
    }).toList();

    final yamlWriter = YamlWriter();
    final yamlString = yamlWriter.write(eintraegeMapList);
    await file.writeAsString(yamlString);
  }

  Future<void> ladeEintraegeAusYaml() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.isEmpty) return;

      final yamlList = loadYaml(content);
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
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/dienste.yaml');
      if (await file.exists()) {
        final yamlString = await file.readAsString();
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

  Future<void> _selectDate(BuildContext context, bool isVon) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = isVon ? (_datumVon ?? now) : (_datumBis ?? now);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isVon) {
          _datumVon = picked;
          _datumVonController.text = _dateFormat.format(picked);
        } else {
          _datumBis = picked;
          _datumBisController.text = _dateFormat.format(picked);
        }
      });
    }
  }

  void _onDatumChanged(String value, bool isVon) {
    try {
      final parsedDate = _dateFormat.parseStrict(value);
      setState(() {
        if (isVon) {
          _datumVon = parsedDate;
        } else {
          _datumBis = parsedDate;
        }
      });
    } catch (e) {
      setState(() {
        if (isVon) {
          _datumVon = null;
        } else {
          _datumBis = null;
        }
      });
    }
  }

  Widget buildNeuerEintragView() {
    return FutureBuilder<List<Person>>(
      future: _personenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Fehler beim Laden der Personen: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('Keine Personen gefunden'));
        } else {
          final personen = snapshot.data!;
          
          if (_ausgewaehltePerson != null && !personen.contains(_ausgewaehltePerson)) {
            _ausgewaehltePerson = null;
          }

          if (_ausgewaehltePerson == null && personen.isNotEmpty) {
            _ausgewaehltePerson = personen.first;
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<Person>(
                  value: _ausgewaehltePerson,
                  decoration: InputDecoration(labelText: "Person auswählen"),
                  items: personen.map((person) {
                    return DropdownMenuItem<Person>(
                      value: person,
                      child: person.getRichTextName(),
                    );
                  }).toList(),
                  onChanged: (Person? neuePerson) {
                    setState(() {
                      _ausgewaehltePerson = neuePerson;
                    });
                  },
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _datumVonController,
                        decoration: InputDecoration(
                          labelText: "Datum von (TT.MM.JJJJ)",
                          hintText: 'z.B. 15.12.2025',
                        ),
                        keyboardType: TextInputType.datetime,
                        onChanged: (value) => _onDatumChanged(value, true),
                      ),
                    ),
                    Ink(
                      decoration: const ShapeDecoration(
                        color: Color(0xFF003399),
                        shape: CircleBorder(),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        color: Colors.white,
                        onPressed: () => _selectDate(context, true),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _datumBisController,
                        decoration: InputDecoration(
                          labelText: "Datum bis (TT.MM.JJJJ)",
                          hintText: 'z.B. 20.12.2025',
                        ),
                        keyboardType: TextInputType.datetime,
                        onChanged: (value) => _onDatumChanged(value, false),
                      ),
                    ),
                    Ink(
                      decoration: const ShapeDecoration(
                        color: Color(0xFF003399),
                        shape: CircleBorder(),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        color: Colors.white,
                        onPressed: () => _selectDate(context, false),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text('Speichern'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF003399),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (_ausgewaehltePerson == null ||
                          _datumVon == null ||
                          _datumBis == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Bitte alle Felder ausfüllen')));
                        return;
                      }
                      if (_datumVon!.isAfter(_datumBis!)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Datum von darf nicht nach Datum bis sein')));
                        return;
                      }
                      setState(() {
                        _eintraege.add(EintragAbwesenheit(_ausgewaehltePerson!, _datumVon!, _datumBis!));
                        _datumVonController.clear();
                        _datumBisController.clear();
                        _datumVon = null;
                        _datumBis = null;
                      });
                      speichereEintraegeInYaml();
                    },
                  ),
                ),
              ],
            ),
          );
        }
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
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Neue Abwesenheit'),
            selected: _auswahl == Ansicht.neuerEintrag,
            onTap: () {
              setState(() {
                _auswahl = Ansicht.neuerEintrag;
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Abwesenheiten ansehen'),
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
      case Ansicht.neuerEintrag:
        title = 'Neue Abwesenheit';
        break;
      case Ansicht.eintraegeAnsehen:
        title = 'Abwesenheiten ansehen';
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
      case Ansicht.neuerEintrag:
        return buildNeuerEintragView();
      case Ansicht.eintraegeAnsehen:
        return AbwesenheitenAnsehenView(
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
              SnackBar(content: Text('Eintrag gelöscht')),
            );
            await speichereEintraegeInYaml();
          },
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