import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:thw_urlaub/dienst.dart';
import 'package:thw_urlaub/person.dart';

enum DienstStatus { x, b, k, u }

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

  @override
  void initState() {
    super.initState();
    _updateSelection();
  }

  @override
  void didUpdateWidget(DienstbeteiligungView oldWidget) {
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
            _anwesenheitsListe[_ausgewaehlterDienst!]![person] = status;
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
          final teilnehmendePersonen = _ausgewaehlterDienst == null
              ? <Person>[]
              : allePersonen.where((p) => _ausgewaehlterDienst!.einheiten.contains(p.einheit)).toList();

          return Column(
            children: [
              DropdownButtonFormField<Dienst>(
                value: _ausgewaehlterDienst,
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