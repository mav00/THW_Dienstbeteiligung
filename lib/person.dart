import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum Funktion { GrFue, TrFue, ZFue, ZTrFue, KF }
enum Einheit { ZTr, B, N, E }

class Person {
  String name;
  String vorname;
  Einheit einheit;
  List<Funktion> funktionen;
  

  Person(this.name, this.vorname, this.einheit, this.funktionen);

  String getFullName() {
    return '$name, $vorname';
  }
  String getEinheit() {
    return einheit.toString().split('.').last;
  }
  String getEinheitFullName() {
    return '${getEinheit()}: $name, $vorname';
  }

  Widget getRichTextName(){
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: getEinheit() + ' - ',
            style: TextStyle(
              color: Color(0xFF003399),
              fontSize: 14,
            ),
          ),
          TextSpan(
            text: getFullName(),
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    List<dynamic> funktionenRaw = map['funktionen'] ?? [];
    List<Funktion> funktionenParsed = funktionenRaw.map((f) {
      switch (f) {
        case 'GrFue':
          return Funktion.GrFue;
        case 'TrFue':
          return Funktion.TrFue;
        case 'ZFue':
          return Funktion.ZFue;
        case 'ZTrFue':
          return Funktion.ZTrFue;
        case 'KF':
          return Funktion.KF;
        default:
          throw Exception('Unbekannte Funktion: $f');
      }
    }).toList();

    Einheit einheitParsed;
    switch (map['einheit']) {
      case 'ZTr':
        einheitParsed = Einheit.ZTr;
        break;
      case 'B':
        einheitParsed = Einheit.B;
        break;
      case 'N':
        einheitParsed = Einheit.N;
        break;
      case 'E':
        einheitParsed = Einheit.E;
        break;
      default:
        einheitParsed = Einheit.ZTr; // Fallback
    }

    return Person(
      map['name'] ?? '',
      map['vorname'] ?? '',
      einheitParsed,
      funktionenParsed,
    );


  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'vorname': vorname,
      'einheit': getEinheit(),
      'funktionen': funktionen.map((f) => f.toString().split('.').last).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Person &&
      other.name == name &&
      other.vorname == vorname &&
      other.einheit == einheit &&
      listEquals(other.funktionen, funktionen);
  }

  @override
  int get hashCode => Object.hash(name, vorname, einheit, Object.hashAll(funktionen));
}
