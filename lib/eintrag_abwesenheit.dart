import 'package:thw_dienstmanager/person.dart';

class EintragAbwesenheit {
  Person person;
  DateTime von;
  DateTime bis;

  EintragAbwesenheit(this.person, this.von, this.bis);
}