# Family Quest – Basisversion 0.2

Installierbare Web-App als Ausgangspunkt für die gemeinsame Weiterentwicklung.

## Start

Im Projektordner einen lokalen Webserver starten, z. B. `python3 -m http.server 8000`, und `http://localhost:8000` öffnen. Das direkte Öffnen der HTML-Datei per `file://` reicht wegen ES-Modulen nicht aus. Für den Zugriff vom iPhone aus ist später HTTPS-Hosting sinnvoll.

## Bereits umgesetzt

- Fünf Beispielprofile (zwei Eltern, drei Kinder), erweiterbar
- Aufgaben mit Zuweisung, regulär/Bonus, Wiederholungskennzeichnung
- Erledigt melden und manuell bestätigen
- XP, Level und Bonusmünzen
- Belohnungen anlegen und einlösen
- Lokale Persistenz per localStorage
- Neues, reduziertes App-Icon als PNG (192 und 512 Pixel), Apple-Touch-Icon und PWA-Manifest

## Nächste Schritte

1. Supabase Auth und Familienmitgliedschaft mit Einladungen
2. Datenmodell mit `families`, `profiles`, `memberships`, `tasks`, `task_completions`, `rewards`, `redemptions`
3. Row Level Security: Familienisolation, Elternrollen serverseitig prüfen; keine Punktegutschrift ohne autorisierte Bestätigung
4. Wiederkehrende Aufgaben mit Fälligkeiten und Zeitfenstern
5. Offline-Synchronisierung, Konfliktbehandlung und PWA-Service-Worker
6. Elternbereich mit gesicherter Freigabe und Benutzerrollen

**Sicherheitshinweis:** Die Demo hat noch keine echte Zugriffskontrolle. Jede Person mit Zugang zum Browser kann Aufgaben bestätigen. Die Demo nicht für sensible Daten oder als produktive Mehrbenutzer-App verwenden.
