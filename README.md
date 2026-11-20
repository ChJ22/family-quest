# Family Quest v0.5 – Supabase-Cloudversion

Basierend auf den hochgeladenen Dateien von Family Quest v0.4. Die ursprünglichen Funktionen für Aufgaben, Elternfreigaben, XP, Münzen und Belohnungen sind übernommen und serverseitig abgesichert.

## Installationsreihenfolge (wichtig)

1. **Supabase SQL Editor**: Im Projekt `Family-Quest` einen **neuen** Query öffnen. Den gesamten Inhalt von `supabase/migration.sql` einfügen und **einmal** ausführen. Das ursprüngliche v0.4-Schema muss bereits vorhanden sein. Bei Erfolg erscheint `Success. No rows returned`.
2. **Supabase Authentication**: Unter `Authentication → Providers → Email` die E-Mail-Anmeldung aktiviert lassen. Bei bestätigungspflichtigen E-Mails muss der Bestätigungslink korrekt funktionieren; unter `Authentication → URL Configuration` die GitHub-Pages-Adresse als erlaubte Redirect-URL hinterlegen (z.B. `https://BENUTZER.github.io/REPOSITORY/**`). Ohne konfigurierten SMTP-Provider kann die Zahl der versendeten E-Mails begrenzt sein.
3. **Edge Function**: `supabase/functions/create-child/index.ts` als Edge Function mit Namen `create-child` in Supabase anlegen und deployen. **JWT verification aktiviert lassen.** Die Funktion nutzt die serverseitigen Supabase-Umgebungsvariablen `SUPABASE_URL`, `SUPABASE_ANON_KEY` und `SUPABASE_SERVICE_ROLE_KEY`. Diese dürfen **niemals** in GitHub-Dateien oder im Browsercode stehen. Für das Deployment kann auch die Supabase CLI verwendet werden: `supabase functions deploy create-child --project-ref zbvmjowlorldtizvfron` (nach CLI-Login und Projekt-Verknüpfung).
4. **GitHub Pages**: Die Dateien `index.html`, `main.js`, `storage.js`, `config.js`, `manifest.webmanifest`, `icon-192.png`, `icon-512.png` in das Stammverzeichnis des Repositories hochladen. Die SQL-Datei und Edge Function gehören **nicht** in das öffentlich ausgelieferte Webverzeichnis (sie sind im ZIP nur als Installationsmaterial enthalten).
5. **Erststart**: In der App `Elternkonto registrieren` wählen, E-Mail bestätigen (falls eingeschaltet), anmelden und `Neue Familie gründen` auswählen. Danach können Eltern im Bereich `Familie` Kinderkonten anlegen. Kinder melden sich mit Benutzername und Passwort an.
6. **Zweites Elternkonto**: Im ersten Elternkonto einen 24 Stunden gültigen Einladungscode erzeugen. Die zweite Person registriert ihr eigenes Elternkonto per E-Mail, meldet sich an und wählt `Familie beitreten`.

## Sicherheit

- Supabase Auth für alle Konten; bei Kindern wird aus dem Benutzernamen eine interne technische Auth-Adresse `benutzername@children.familyquest.invalid` gebildet. Das Kind braucht kein eigenes E-Mail-Postfach.
- Die Kinderkonten werden nur von einer angemeldeten Person mit serverseitig geprüfter Elternrolle über die Edge Function angelegt. **Kinderpasswörter müssen die Eltern sicher verwalten**; für diese technischen Konten gibt es noch keinen selbstständigen Passwort-Reset per E-Mail.
- RLS begrenzt Lesezugriffe auf die eigene Familie. Direkte Schreibzugriffe auf Tabellen sind gesperrt; `fq_action` prüft Rolle, Familienzugehörigkeit, Status und Punkte serverseitig. Das Erzeugen von Guthaben und Einlösen von Belohnungen erfolgt transaktional.
- Das erste Elternkonto kann eine eigene neue Familie anlegen. Weitere Elternkonten benötigen einen Einladungscode.
- `config.js` enthält nur die öffentlich nutzbare Projekt-URL und den Publishable Key. Diese sind keine Geheimnisse. **Secret-/Service-Role-Key und Datenbankpasswort niemals dort eintragen.**

## Noch nicht enthalten

- Automatische Neuerstellung täglich/wöchentlich wiederkehrender Aufgaben (wie in v0.4 nur als Kennzeichnung vorhanden).
- Level-4-Familien-Challenges.
- Selbstständiger Passwort-Reset für Kinder, Änderung von Kinderpasswörtern, Kontolöschung und Familienwechsel.
- Live-Push-Updates; `Aktualisieren` ruft den aktuellen Datenstand ab.
- Automatische Übernahme der alten Browser-Demodaten. Die neue Cloud-Familie startet leer.

## Technischer Hinweis

Diese Version ist als installierbare Implementierung vorbereitet, aber noch nicht gegen das echte Supabase-Projekt ausgeführt oder mit mehreren Geräten end-to-end getestet. Die SQL-Migration muss vor dem Einsatz der App erfolgreich ausgeführt werden; ohne Edge-Function-Deployment können Kinderkonten nicht angelegt werden. Bitte zunächst mit Testdaten prüfen.
