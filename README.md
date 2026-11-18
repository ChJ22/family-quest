# Family Quest v0.4 – Familienaufgaben und Monatslevel

## Regeln
- Eltern: volle Verwaltungsrechte, keine XP, können Münzen für bestätigte Aufgaben erhalten.
- Kinder: erhalten für bestätigte Aufgaben XP und Münzen.
- Ab 60 Monats-XP (Level 2): Belohnungen vorschlagen, die Eltern freigeben.
- Ab 120 Monats-XP (Level 3): Wochenendaufgaben auch für Eltern vorschlagen; Eltern müssen freigeben.
- Ab 200 Monats-XP (Level 4): Familien-Challenges als nächster Ausbauschritt vorgesehen.
- Monatserster: Kinder-XP zurück auf 0; Münzen und Karriere-XP bleiben erhalten.
- Münzen werden beim Einlösen einer Belohnung abgezogen.

## Start / GitHub Pages
Dateien im Ordner `family-quest` in das Wurzelverzeichnis des GitHub-Repositories hochladen. GitHub Pages: Settings → Pages → Deploy from a branch → main / (root).

## Datenbank als nächster Schritt
`storage.js` ist der lokale Speicheradapter (`load`/`save`). Als nächstes Supabase Auth, Familienzugehörigkeit, Rollen und Row Level Security einrichten. Die Demo-Rollenumschaltung ist **keine sichere Anmeldung**. Bis dahin nur Testdaten verwenden.

## Noch offen
Wiederkehrende Aufgaben werden noch nicht automatisch neu erstellt. Aufgaben- und Belohnungsvorschläge müssen von Eltern freigegeben werden. Level-4-Challenges werden in einer späteren Version ergänzt.
