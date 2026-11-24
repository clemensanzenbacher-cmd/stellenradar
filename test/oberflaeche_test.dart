import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stellenradar/daten.dart';
import 'package:stellenradar/main.dart';
import 'package:stellenradar/modelle.dart';

class TestQuelle implements Datenquelle {
  final StellenDaten daten;
  TestQuelle(this.daten);
  @override
  Stream<StellenDaten> stellen() => Stream.value(daten);
}

final jetztFest = DateTime(2026, 11, 24, 12);

StellenDaten beispiel() => StellenDaten(
      letzterLauf: jetztFest.subtract(const Duration(minutes: 30)),
      stellen: [
        Stelle(
            id: 'a',
            titel: 'Praktikum im Bereich Konstruktion (m/w/d)',
            firma: 'Liebherr',
            ort: 'Ehingen',
            land: 'DE',
            url: 'https://example.org/a',
            quelle: 'careers.liebherr.com',
            ersterfasst: jetztFest.subtract(const Duration(hours: 1)),
            neu: true),
        Stelle(
            id: 'b',
            titel: 'Intern Materials & Processes Engineer',
            firma: 'Beyond Gravity',
            ort: 'Zürich',
            land: 'CH',
            url: 'https://example.org/b',
            quelle: 'careers.beyondgravity.com',
            sprache: 'en',
            englischPflicht: true,
            ersterfasst: jetztFest.subtract(const Duration(days: 5))),
      ],
    );

void main() {
  test('Filter: nur deutsche Anzeigen und Länder', () async {
    final z = AppZustand(quelle: TestQuelle(beispiel()), uhr: () => jetztFest)..starte();
    await Future<void>.delayed(Duration.zero);
    expect(z.sichtbar.map((s) => s.id), ['a', 'b']);
    expect(z.neuAnzahl, 1);
    z.setzeNurDeutsch(true);
    expect(z.sichtbar.map((s) => s.id), ['a']);
    z.setzeNurDeutsch(false);
    z.setzeLand('DE', false);
    expect(z.sichtbar.map((s) => s.id), ['b']);
    z.umschaltenBeworben('b');
    expect(z.sichtbar, isEmpty);
    expect(z.merkliste.map((s) => s.id), ['b']);
  });

  test('Daten aus Firestore lesen', () {
    final d = StellenDaten.ausDaten({
      'letzterLauf': '2026-11-24T10:00:00+00:00',
      'stellen': [
        {'id': 'x', 'titel': 'T', 'firma': 'F', 'url': 'https://e.org', 'ersterfasst': '2026-11-24T10:00:00+00:00',
         'englischPflicht': null, 'sprache': 'de', 'aktiv': true},
        {'id': '', 'url': ''},
      ],
      'quellen': {'WinGD': {'ok': true, 'gefunden': 3, 'passend': 1, 'fehler': ''}},
    });
    expect(d.stellen.length, 1);
    expect(d.stellen.first.deutschFreundlich, isTrue);
    expect(d.quellen.single.passend, 1);
  });

  testWidgets('Startseite zeigt Stellen und öffnet Details', (tester) async {
    final z = AppZustand(quelle: TestQuelle(beispiel()), uhr: () => jetztFest)..starte();
    await tester.pumpWidget(StellenRadarApp(zustand: z, mitPush: false));
    await tester.pumpAndSettle();
    expect(find.text('Praktikum im Bereich Konstruktion (m/w/d)'), findsOneWidget);
    expect(find.text('NEU'), findsOneWidget);
    expect(find.text('Englisch verlangt'), findsOneWidget);
    await tester.tap(find.text('Praktikum im Bereich Konstruktion (m/w/d)'));
    await tester.pumpAndSettle();
    expect(find.text('Anzeige öffnen'), findsOneWidget);
    expect(z.gesehen.contains('a'), isTrue);
    z.dispose();
  });
}
