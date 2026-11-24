# StellenRadar

Sucht alle 2 Stunden neue **Praktika, Internships und Trainee-Stellen mit Maschinenbau-Bezug** (Schweiz, Liechtenstein, Deutschland, Österreich) und meldet sie per Push aufs Android-Handy. Aufbau wie GenoRadar: GitHub Actions + Firebase (gleiches Firebase-Projekt `genoradar`) + Flutter-App. Kein KI-Aufruf, keine Tokens.

```
GitHub Actions (öffentlich, alle 2 Std)        Firebase (Projekt genoradar)           Handy
waechter/waechter.py ── Liste ──▶  Firestore meta/stellen   ◀── liest ── StellenRadar-App
   │ jobs.ch, jobup.ch, Liebherr, WinGD, Beyond Gravity, Bühler, SVTI, TÜV SÜD
   └─ Push (nur neue Stellen mit geprüftem Link) ─▶ Cloud Messaging, Thema „stellen“ ─▶ Benachrichtigung
```

- **Filter:** Titel muss Praktikum/Intern/Trainee/Young Talent/Graduate sein (keine Schüler-, Werkstudenten-, Lehrstellen) und Maschinenbau-Bezug haben (Konstruktion, Entwicklung, Produktion, Qualität, Test, Simulation, Luft- und Raumfahrt …). Regeln: `waechter/waechter.py` (ART, FACH, NICHT_FACH).
- **Sprache:** Jede Stelle bekommt „Deutsch“ oder „Anzeige Englisch/Französisch“, bei jobs.ch zusätzlich „Englisch verlangt“. In der App: Filter „Nur deutsche Anzeigen“.
- **Links:** Neue Stellen werden vor der Meldung geöffnet; nur funktionierende Links (Status 200, keine Umleitung auf die Suche) werden gemeldet.
- **Erster Lauf:** merkt sich den Ist-Stand ohne Push.

## Pflege
- Firma mit SuccessFactors-Karriereseite ergänzen: `waechter/quellen.json` › `successfactors`.
- Lokal testen: `cd waechter ; python waechter.py --trocken` und `python -m unittest discover tests`.
- Test-Push: GitHub › Actions › Stellen-Wächter › Run workflow › Haken „Test-Benachrichtigung“.
