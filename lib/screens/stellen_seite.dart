import 'package:flutter/material.dart';

import '../daten.dart';
import '../modelle.dart';
import '../theme.dart';
import '../widgets/bausteine.dart';
import '../widgets/stellen_karte.dart';

class StellenSeite extends StatelessWidget {
  final VoidCallback? zuEinstellungen;
  const StellenSeite({super.key, this.zuEinstellungen});

  @override
  Widget build(BuildContext context) {
    final z = Zustand.von(context);
    final liste = z.sichtbar;
    final neu = z.neuAnzahl;
    final letzter = z.daten.letzterLauf;
    final verspaetet = z.geladen && z.fehler == null && waechterVerspaetet(letzter, z.jetzt());

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.engineering, color: Farben.akzent, size: 28),
                  const SizedBox(width: 10),
                  Expanded(child: Text('StellenRadar', style: Schrift.h1(25))),
                  RundKnopf(Icons.notifications_none, 'Benachrichtigungen', onTap: zuEinstellungen),
                ]),
                const SizedBox(height: 6),
                Text(
                  [
                    'Praktika & Trainee · Maschinenbau',
                    if (letzter != null) 'letzter Check ${vorZeit(letzter, z.jetzt())}',
                  ].join(' · '),
                  style: Schrift.klein(Farben.textGedaempft, 13),
                ),
              ],
            ),
          ),
        ),
        if (z.fehler != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Hinweis.fehler('Keine Verbindung zur Datenbank: ${z.fehler}'),
            ),
          ),
        if (verspaetet)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Hinweis(letzter == null
                  ? 'Der Wächter hat noch keine Daten geliefert. Der erste Lauf kommt in GitHub › Actions.'
                  : 'Der Wächter hat sich seit ${vorZeit(letzter, z.jetzt())} nicht gemeldet '
                      '(normal: alle 2 Stunden). GitHub › Actions prüfen.'),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              onChanged: z.setzeSuche,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: Farben.textGedaempft),
                hintText: 'Suchen (Firma, Ort, Stichwort)',
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(children: [
              _Chip('Nur deutsche Anzeigen', z.nurDeutsch, (v) => z.setzeNurDeutsch(v)),
              for (final land in const ['CH', 'DE', 'AT', 'LI'])
                _Chip(laenderNamen[land]!, z.laender.contains(land), (v) => z.setzeLand(land, v)),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 6),
            child: Row(children: [
              Expanded(
                child: Text(
                  !z.geladen ? 'Lade …' : '${liste.length} Stellen${neu > 0 ? ' · $neu neu' : ''}',
                  style: Schrift.etikett(),
                ),
              ),
              if (neu > 0)
                TextButton(onPressed: z.alleGesehen, child: const Text('Alle als gesehen')),
            ]),
          ),
        ),
        if (z.geladen && liste.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                z.daten.stellen.isEmpty
                    ? 'Noch keine Stellen. Sobald der Wächter läuft, erscheinen sie hier.'
                    : 'Keine Stelle passt zu den Filtern.',
                style: Schrift.body(14, Farben.textMittel),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList.separated(
            itemCount: liste.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => StellenKarte(liste[i]),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final bool an;
  final ValueChanged<bool> wechsel;
  const _Chip(this.text, this.an, this.wechsel);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(text),
          selected: an,
          onSelected: wechsel,
          selectedColor: Farben.akzentFlaeche,
          checkmarkColor: Farben.akzent,
          backgroundColor: Farben.flaeche,
          side: BorderSide(color: an ? Farben.akzentRand : Farben.linieHell),
          labelStyle: Schrift.klein(an ? Farben.akzentHell : Farben.textMittel, 13),
        ),
      );
}
