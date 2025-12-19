import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:thw_urlaub/dienst.dart';
import 'package:thw_urlaub/person.dart';
import 'package:thw_urlaub/dienst_status.dart';

class PdfExportService {
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');

  Future<File> exportSingleServicePdf(
      Dienst dienst,
      List<Person> personen,
      Map<Person, DienstStatus> statusMap) async {
    final pdf = pw.Document();
    
    // Filter and sort participants
    final teilnehmende = personen.where((p) => dienst.einheiten.contains(p.einheit)).toList();
    teilnehmende.sort((a, b) => a.name.compareTo(b.name));

    final dateStr = _dateFormat.format(dienst.datum);
    final unitsStr = dienst.einheiten.map((e) => e.toString().split('.').last).join(', ');

    // Calculate stats
    int anwesende = statusMap.values.where((s) => s == DienstStatus.x).length;
    int anwesendeKF = statusMap.entries.where((e) => 
      e.value == DienstStatus.x && e.key.funktionen.contains(Funktion.KF)
    ).length;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Dienstauswertung $dateStr', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Text('Einheiten: $unitsStr'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['Nachname', 'Vorname', 'Funktion', 'Status'],
                data: teilnehmende.map((p) {
                  final status = statusMap[p];
                  return [
                    p.name,
                    p.vorname,
                    p.funktionen.map((f) => f.toString().split('.').last).join(', '),
                    status?.name.toUpperCase() ?? '-',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Zusammenfassung:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Anwesende Helfer: $anwesende'),
              pw.Text('Anwesende Kraftfahrer: $anwesendeKF'),
            ],
          );
        },
      ),
    );

    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/Dienst_$dateStr.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File?> exportYearlyPdf(
      int year,
      List<Dienst> dienste,
      List<Person> personen,
      Map<Dienst, Map<Person, DienstStatus>> anwesenheitsListe) async {
    
    final servicesOfYear = dienste.where((d) => d.datum.year == year).toList();
    servicesOfYear.sort((a, b) => a.datum.compareTo(b.datum));

    if (servicesOfYear.isEmpty) {
      return null;
    }

    final sortedPersonen = List<Person>.from(personen);
    sortedPersonen.sort((a, b) => a.name.compareTo(b.name));

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Jahresübersicht $year', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Name, Vorname', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    ...servicesOfYear.map((d) {
                      final dateStr = _dateFormat.format(d.datum).substring(0, 5);
                      final unitsStr = d.einheiten.map((e) => e.toString().split('.').last).join('\n');
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Column(
                          children: [
                            pw.Text(dateStr, style: const pw.TextStyle(fontSize: 8)),
                            pw.Text(unitsStr, style: const pw.TextStyle(fontSize: 6), textAlign: pw.TextAlign.center),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
                ...sortedPersonen.map((p) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('${p.name}, ${p.vorname}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      ...servicesOfYear.map((d) {
                        String cellText = '-';
                        PdfColor? cellColor;
                        
                        if (!d.einheiten.contains(p.einheit)) {
                          cellText = 'NR';
                          cellColor = PdfColors.grey200;
                        } else {
                          final status = anwesenheitsListe[d]?[p];
                          if (status != null) {
                            cellText = status.name.toUpperCase();
                          }
                        }
                        
                        return pw.Container(
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.all(4),
                          color: cellColor,
                          child: pw.Text(cellText, style: const pw.TextStyle(fontSize: 8)),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/Jahresuebersicht_$year.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}