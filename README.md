# Family Quest – Basisversion 0.3

Installierbare PWA-Basis mit bestehendem App-Icon und lokalem Speicheradapter.

## Neu in 0.3
- Monats-XP: Reset beim ersten Öffnen in einem neuen Kalendermonat; Monatsabschluss im Archiv
- Karriere-XP: dauerhaft; Münzen: dauerhaft, auch über Monatsgrenzen
- Kinderlevel: 1 (0 XP), 2 (100), 3 (250), 4 (450), 5 (700)
- Level 3: Aufgaben vorschlagen; Level 4: eigene Aufgaben erstellen, zunächst mit Elternfreigabe; Level 5: auch anderen Familienmitgliedern Aufgaben vorschlagen
- Eltern: jederzeit volle Verwaltungsrechte, bestätigen Erledigungen und Vorschläge
- Profilumschalter zum Ausprobieren der Rollen; KEINE echte Authentifizierung
- Bestehende lokale Daten aus `familyquest-v1` werden beim Laden um Karriere-XP/Monatsinformationen ergänzt.

## GitHub Pages
Repository `family-quest` anlegen, **Inhalt dieses Ordners** (nicht den Ordner selbst) ins Repository-Hauptverzeichnis hochladen. Unter Settings → Pages: Deploy from a branch, `main`, `/(root)` wählen. `index.html` muss im Hauptverzeichnis liegen.

## Lokal testen
Mit einem lokalen HTTP-Server starten, z. B. `python -m http.server 8000` im Projektordner; dann `http://localhost:8000` öffnen. ES-Module funktionieren nicht zuverlässig über `file://`.

## Spätere Datenbank
`storage.js` ist der lokale Adapter mit `load()` / `save()`. Für Supabase brauchen wir echte Authentifizierung, Familienzuordnung (`family_id`), serverseitige Rollenprüfung / Row Level Security, sichere Transaktionen für XP/Münzen, Monatsabschluss und Synchronisierung. Die Demo-Profilumschaltung bietet **keine Zugriffssicherheit**.

## Noch offen
Automatische tägliche/wöchentliche Wiederholung; eigene Aufgabenrechte und Challenges feiner gestalten; vollständige Elternprüfung für Belohnungen; Monatsauszeichnungen; echte Mehrgeräte-Synchronisierung.
