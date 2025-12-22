import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';
import 'package:thw_dienstmanager/person.dart';
import 'package:thw_dienstmanager/api_service.dart';

class HelferdatenPage extends StatefulWidget {
  @override
  _HelferdatenPageState createState() => _HelferdatenPageState();
}

class _HelferdatenPageState extends State<HelferdatenPage> {
  List<Person> _personen = [];
  bool _isLoading = true;

  Future<void> ladePersonen() async {
    List<Person> geladenePersonen = [];
    final data = await ApiService.loadYamlData('persons.yaml');
    
    if (data is YamlList) {
      geladenePersonen = data.map((e) => Person.fromMap(Map<String, dynamic>.from(e))).toList();
    }

    if (mounted) {
      setState(() {
        _personen = geladenePersonen;
        _isLoading = false;
      });
    }
  }

  Future<void> speichereListe() async {
    await ApiService.saveYamlData('persons.yaml', _personen.map((p) => p.toMap()).toList());
  }

  void _bearbeiteOderErstellePerson({Person? person, int? index}) {
    final nameController = TextEditingController(text: person?.name ?? '');
    final vornameController = TextEditingController(text: person?.vorname ?? '');
    Einheit ausgewaehlteEinheit = person?.einheit ?? Einheit.ZTr;
    List<Funktion> ausgewaehlteFunktionen = person != null ? List.from(person.funktionen) : [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(person == null ? 'Neuen Helfer anlegen' : 'Helfer bearbeiten'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: vornameController,
                      decoration: InputDecoration(labelText: 'Vorname'),
                    ),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: 'Name'),
                    ),
                    DropdownButtonFormField<Einheit>(
                      value: ausgewaehlteEinheit,
                      dropdownColor: Colors.white,
                      decoration: InputDecoration(labelText: 'Einheit'),
                      items: Einheit.values.map((e) {
                        return DropdownMenuItem(
                          value: e,
                          child: Text(e.toString().split('.').last),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => ausgewaehlteEinheit = v);
                      },
                    ),
                    SizedBox(height: 16),
                    Text('Funktionen:'),
                    Wrap(
                      spacing: 8.0,
                      children: Funktion.values.map((f) {
                        final isSelected = ausgewaehlteFunktionen.contains(f);
                        return FilterChip(
                          label: Text(f.toString().split('.').last),
                          selected: isSelected,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                ausgewaehlteFunktionen.add(f);
                              } else {
                                ausgewaehlteFunktionen.remove(f);
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
                    if (nameController.text.isNotEmpty && vornameController.text.isNotEmpty) {
                      final neuePerson = Person(nameController.text, vornameController.text, ausgewaehlteEinheit, ausgewaehlteFunktionen);
                      setState(() {
                        if (index != null) {
                          _personen[index!] = neuePerson;
                        } else {
                          _personen.add(neuePerson);
                        }
                      });
                      speichereListe();
                      Navigator.pop(context);
                    }
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

  void _loeschePerson(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Helfer löschen'),
        content: Text('Möchten Sie ${_personen[index].getFullName()} wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Abbrechen')),
          TextButton(
            onPressed: () {
              setState(() {
                _personen.removeAt(index);
              });
              speichereListe();
              Navigator.pop(context);
            },
            child: Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    ladePersonen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('Neuen Helfer hinzufügen'),
                onPressed: () => _bearbeiteOderErstellePerson(),
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
                : _personen.isEmpty
                    ? Center(child: Text('Keine Personen gefunden'))
                    : ListView.builder(
                        itemCount: _personen.length,
                        itemBuilder: (context, index) {
                          final person = _personen[index];
                          return ListTile(
                            title: person.getRichTextName(),
                            subtitle: Text(
                                'Funktionen: ${person.funktionen.map((f) => f.toString().split('.').last).join(', ')}'),
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
                                    onPressed: () => _bearbeiteOderErstellePerson(person: person, index: index),
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
                                    onPressed: () => _loeschePerson(index),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}