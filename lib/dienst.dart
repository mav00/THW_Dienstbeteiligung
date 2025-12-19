import 'package:thw_dienstmanager/person.dart';
import 'package:flutter/foundation.dart';

class Dienst {
  DateTime datum;
  List<Einheit> einheiten;

  Dienst(this.datum, this.einheiten);

  Map<String, dynamic> toMap() {
    return {
      'datum': datum.toIso8601String(),
      'einheiten': einheiten.map((e) => e.toString().split('.').last).toList(),
    };
  }

  factory Dienst.fromMap(Map<String, dynamic> map) {
    DateTime date = DateTime.parse(map['datum']);
    List<dynamic> unitsRaw = map['einheiten'] ?? [];
    List<Einheit> units = unitsRaw.map((u) {
      return Einheit.values.firstWhere(
        (e) => e.toString().split('.').last == u,
        orElse: () => Einheit.ZTr, 
      );
    }).toList();
    return Dienst(date, units);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Dienst &&
      other.datum == datum &&
      listEquals(other.einheiten, einheiten);
  }

  @override
  int get hashCode => Object.hash(datum, Object.hashAll(einheiten));
}