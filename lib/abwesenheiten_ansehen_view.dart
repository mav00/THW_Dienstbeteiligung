import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:thw_dienstmanager/eintrag_abwesenheit.dart';

class AbwesenheitenAnsehenView extends StatelessWidget {
  final List<EintragAbwesenheit> eintraege;
  final DateTime? filterDatum;
  final ValueChanged<DateTime?> onFilterDatumChanged;
  final ValueChanged<EintragAbwesenheit> onEintragRemoved;

  AbwesenheitenAnsehenView({
    Key? key,
    required this.eintraege,
    required this.filterDatum,
    required this.onFilterDatumChanged,
    required this.onEintragRemoved,
  }) : super(key: key);

  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');

  Future<void> _pickFilterDatum(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = filterDatum ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onFilterDatumChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(filterDatum == null
                ? 'Gefiltertes Datum: Alle ausstehenden'
                : 'Gefiltertes Datum: ${_dateFormat.format(filterDatum!)}'),
            Row(
              children: [
                Ink(
                  decoration: const ShapeDecoration(
                    color: Color(0xFF003399),
                    shape: CircleBorder(),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    color: Colors.white,
                    onPressed: () => _pickFilterDatum(context),
                  ),
                ),
                if (filterDatum != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Ink(
                      decoration: const ShapeDecoration(
                        color: Color(0xFF003399),
                        shape: CircleBorder(),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.clear),
                        color: Colors.white,
                        tooltip: 'Filter löschen',
                        onPressed: () {
                          onFilterDatumChanged(null);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Divider(),
        Expanded(
          child: Builder(
            builder: (context) {
              List<EintragAbwesenheit> anzuzeigendeEintraege;
              final heute = DateTime.now();
              final heuteOhneZeit = DateTime(heute.year, heute.month, heute.day);

              if (filterDatum == null) {
                anzuzeigendeEintraege = eintraege.where(
                  (e) => !e.bis.isBefore(heuteOhneZeit),
                ).toList();
              } else {
                anzuzeigendeEintraege = eintraege.where(
                  (e) =>
                      !(filterDatum!.isBefore(e.von)) &&
                      !(filterDatum!.isAfter(e.bis)),
                ).toList();
              }

              if (anzuzeigendeEintraege.isEmpty) {
                return Center(child: Text('Keine Einträge gefunden'));
              }

              return ListView.builder(
                itemCount: anzuzeigendeEintraege.length,
                itemBuilder: (context, index) {
                  final eintrag = anzuzeigendeEintraege[index];
                  return ListTile(
                    title: eintrag.person.getRichTextName(),
                    subtitle: Text(
                        'Von: ${_dateFormat.format(eintrag.von)} Bis: ${_dateFormat.format(eintrag.bis)}'),
                    trailing: Ink(
                      decoration: const ShapeDecoration(
                        color: Color(0xFF003399),
                        shape: CircleBorder(),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete),
                        color: Colors.white,
                        onPressed: () async {
                          final bool? bestaetigt = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Eintrag löschen'),
                              content: Text('Möchten Sie diesen Eintrag wirklich löschen?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: Text('Nein'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: Text('Ja'),
                                ),
                              ],
                            ),
                          );

                          if (bestaetigt == true) {
                            onEintragRemoved(eintrag);
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}