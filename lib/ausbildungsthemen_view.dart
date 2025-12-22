import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:thw_dienstmanager/dienst.dart';
import 'package:thw_dienstmanager/person.dart';
import 'package:thw_dienstmanager/api_service.dart';
import 'package:yaml/yaml.dart';

class AusbildungsthemenView extends StatefulWidget {
  final List<Dienst> dienste;

  const AusbildungsthemenView({Key? key, required this.dienste}) : super(key: key);

  @override
  _AusbildungsthemenViewState createState() => _AusbildungsthemenViewState();
}

class _AusbildungsthemenViewState extends State<AusbildungsthemenView> {
  Dienst? _ausgewaehlterDienst;
  final Map<String, Map<String, String>> _themenListe = {};
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _updateSelection();
    _loadThemen();
  }

  @override
  void didUpdateWidget(AusbildungsthemenView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dienste != oldWidget.dienste) {
      _updateSelection();
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

  Future<void> _loadThemen() async {
    final data = await ApiService.loadYamlData('ausbildungsthemen.yaml');
    if (data is YamlList) {
      for (var entry in data) {
        final dateStr = entry['date'];
        final topics = entry['topics'] as List;
        final Map<String, String> unitTopics = {};
        for (var t in topics) {
          unitTopics[t['unit']] = t['text'];
        }
        _themenListe[dateStr] = unitTopics;
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveThemen() async {
    final List<Map<String, dynamic>> exportList = [];
    _themenListe.forEach((date, topics) {
      if (topics.isNotEmpty) {
        final List<Map<String, String>> topicList = [];
        topics.forEach((unit, text) {
          if (text.isNotEmpty) {
            topicList.add({'unit': unit, 'text': text});
          }
        });
        if (topicList.isNotEmpty) {
          exportList.add({
            'date': date,
            'topics': topicList,
          });
        }
      }
    });
    await ApiService.saveYamlData('ausbildungsthemen.yaml', exportList);
  }

  void _editTopic(Einheit einheit, String currentText) {
    final textController = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Themen für ${einheit.toString().split('.').last} bearbeiten'),
        content: TextField(
          controller: textController,
          maxLines: 10,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Themen hier eingeben...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final dateStr = _dateFormat.format(_ausgewaehlterDienst!.datum);
              final unitStr = einheit.toString().split('.').last;
              
              if (!_themenListe.containsKey(dateStr)) {
                _themenListe[dateStr] = {};
              }
              _themenListe[dateStr]![unitStr] = textController.text;
              
              await _saveThemen();
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ausbildungsthemen gespeichert')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003399),
              foregroundColor: Colors.white,
            ),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dienste.isEmpty) {
      return const Center(child: Text('Keine Dienste vorhanden.'));
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButtonFormField<Dienst>(
            value: _ausgewaehlterDienst,
            decoration: const InputDecoration(
              labelText: "Dienst auswählen",
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
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
        ),
        Expanded(
          child: _ausgewaehlterDienst == null
              ? const SizedBox()
              : ListView(
                  padding: const EdgeInsets.all(8.0),
                  children: _ausgewaehlterDienst!.einheiten.map((einheit) {
                    final dateStr = _dateFormat.format(_ausgewaehlterDienst!.datum);
                    final unitStr = einheit.toString().split('.').last;
                    final currentText = _themenListe[dateStr]?[unitStr] ?? '';

                    return Card(
                      key: ValueKey('${dateStr}_$unitStr'),
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Ausbildungsinhalt für $unitStr',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF003399)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Color(0xFF003399)),
                                  onPressed: () => _editTopic(einheit, currentText),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentText.isEmpty ? 'Keine Themen eingetragen.' : currentText,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}