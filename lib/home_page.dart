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

enum Ansicht { eintraegeAnsehen, neuerEintrag, dienstbeteiligung }

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

  AppBar getAppBar() {
    return AppBar(
      backgroundColor: Color(0xFF003399),
      foregroundColor: Colors.white,
      centerTitle: true,
      leading: Image.asset(
        'assets/logo.jpg',
        fit: BoxFit.contain,
      ),
      leadingWidth: 160,
      title: Text('Abwesenheiten 1.TZ'),
      actions: [
        IconButton(
          icon: Icon(Icons.calendar_month),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DienstePage()),
            );
            ladeDiensteAusYaml(); // Dienste neu laden, falls welche hinzugefügt/gelöscht wurden
          },
        ),
        IconButton(
          icon: Icon(Icons.person),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HelferdatenPage()),
            );
            setState(() {
              _personenFuture = ladePersonenAusYaml();
            });
          },
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: getAppBar(),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            ToggleButtons(
              isSelected: [
                _auswahl == Ansicht.neuerEintrag,
                _auswahl == Ansicht.eintraegeAnsehen,
                _auswahl == Ansicht.dienstbeteiligung,
              ],
              onPressed: (int index) {
                setState(() {
                  _auswahl = (index == 0)
                      ? Ansicht.neuerEintrag
                      : (index == 1)
                          ? Ansicht.eintraegeAnsehen
                          : Ansicht.dienstbeteiligung;
                });
              },
              borderRadius: BorderRadius.circular(4),
              hoverColor: Colors.blueGrey,
              selectedBorderColor: Color(0xff000000),
              selectedColor: Colors.white,
              fillColor: Color(0xFF003399),
              color: const Color.fromARGB(255, 0, 0, 0),
              constraints: BoxConstraints(minHeight: 40, minWidth: 150),
              children: [
                Text(' Neue Abwesenheit eintragen '),
                Text(' Abwesenheiten einsehen '),
                Text(' Dienstbeteiligung '),
              ],
            ),
            Divider(),
            Expanded(
              child: _auswahl == Ansicht.neuerEintrag
                  ? buildNeuerEintragView()
                  : _auswahl == Ansicht.eintraegeAnsehen
                      ? AbwesenheitenAnsehenView(
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
                        )
                      : DienstbeteiligungView(
                          dienste: _dienste,
                          personenFuture: _personenFuture,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}