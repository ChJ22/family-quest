# Family Quest – Datenbankdateien

Die vier `database_*.sql`-Dateien liegen absichtlich im Hauptverzeichnis, damit sie auf dem iPhone einfach mit GitHub hochgeladen werden können.

- `database_schema.sql`: Dokumentation der exportierten Spalten, Constraints und Indizes; **kein vollständiges Wiederherstellungsskript**.
- `database_functions.sql`: Export der bestehenden Funktionen; **nicht ungeprüft ausführen**.
- `database_policies.sql`: Dokumentation der exportierten RLS-Regeln.
- `database_migration_001.sql`: **Platzhalter**, noch keine ausführbare Migration.

GitHub führt SQL nicht in Supabase aus. Keine CSV mit echten Benutzerdaten, Passwörter, Service-Role-Schlüssel oder andere Geheimnisse hochladen. Vor einem Upload `config.js` auf geheime Schlüssel prüfen; ein öffentlicher Supabase-Publishable-/Anon-Key ist hingegen für Client-Apps vorgesehen.

Der übrige App-Code wurde aus dem hochgeladenen Projekt unverändert übernommen.
