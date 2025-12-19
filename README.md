# THW Dienstbeteiligung & Abwesenheitsverwaltung

Diese Flutter-Anwendung dient der Verwaltung von Dienstbeteiligungen und Abwesenheiten für Einheiten des Technischen Hilfswerks (z.B. 1. TZ). Sie ermöglicht eine einfache Erfassung von Anwesenheiten bei Diensten sowie die Planung von Abwesenheiten.

## Funktionen

*   **Abwesenheiten verwalten**:
    *   Eintragen von Abwesenheitszeiträumen für Helfer.
    *   Übersicht über geplante Abwesenheiten.
    *   Filterung nach Datum.
*   **Dienstbeteiligung erfassen**:
    *   Auswahl aus geplanten Diensten.
    *   Erfassung des Status pro Helfer:
        *   **x**: Anwesend (Grün)
        *   **b**: Beurlaubt / Befreit (Gelb)
        *   **k**: Krank (Gelb)
        *   **u**: Unentschuldigt (Rot)
    *   Automatische Zählung der anwesenden Gesamtstärke und Kraftfahrer (KF).
*   **Stammdatenverwaltung**:
    *   Verwaltung von Helferdaten (Personen, Einheiten, Funktionen).
    *   Verwaltung von Dienstterminen.
*   **Lokale Datenspeicherung**: Die Datenhaltung erfolgt lokal über YAML-Dateien, was einen einfachen Austausch und Transparenz ermöglicht.

## Voraussetzungen

*   [Flutter SDK](https://flutter.dev/docs/get-started/install)
*   Dart SDK

## Installation & Ausführung

1.  Repository klonen oder herunterladen.
2.  Abhängigkeiten installieren:
    ```bash
    flutter pub get
    ```
3.  App starten (z.B. als Linux Desktop App oder auf Android):
    ```bash
    flutter run
    ```

## Datenstruktur

Die Anwendung speichert Daten im lokalen Dokumentenverzeichnis der Anwendung in YAML-Dateien:

*   `persons.yaml`: Enthält die Liste der Helfer inkl. Funktionen (z.B. KF) und Einheit.
*   `dienste.yaml`: Liste der angelegten Dienste.
*   `abwesenheiten.yaml`: Gespeicherte Abwesenheitseinträge (Von-Bis Datum).