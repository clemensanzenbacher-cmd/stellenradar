import 'package:flutter/material.dart';

import '../daten.dart';
import '../modelle.dart';
import '../theme.dart';
import '../widgets/bausteine.dart';
import '../widgets/stellen_karte.dart';

/// Details einer Stelle als Blatt von unten. Markiert die Stelle als gesehen.
Future<void> zeigeStelle(BuildContext context, Stelle s) {
  Zustand.lesen(context).markiereGesehen(s.id);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _StelleBlatt(id: s.id, vorlage: s),
  );
}

class _StelleBlatt extends StatelessWidget {
  final String id;
  final Stelle vorlage;
  const _StelleBlatt({required this.id, required this.vorlage});

  @override
  Widget build(BuildContext context) {
    final z = Zustand.von(context);
    final s = z.stelleNachId(id) ?? vorlage;
    final gemerkt = z.gemerkt.contains(s.id);
    final beworben = z.beworben.contains(s.id);
    final ausgeblendet = z.ausgeblendet.contains(s.id);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text(s.firma, style: Schrift.body(14, Farben.textMittel, FontWeight.w700)),
          const SizedBox(height: 4),
          Text(s.titel, style: Schrift.h1(22)),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (s.ortText.isNotEmpty) Etikett(s.ortText),
            ...sprachEtiketten(s),
            if (!s.aktiv) const Etikett('nicht mehr online', grund: Farben.fehlerFlaeche, farbe: Farben.fehler),
          ]),
          const SizedBox(height: 16),
          _Zeile('Gefunden', '${datumText(s.ersterfasst)} (${vorZeit(s.ersterfasst, z.jetzt())})'),
          if (s.datum != null) _Zeile('Veröffentlicht', datumText(s.datum!)),
          _Zeile('Quelle', s.quelle),
          if (s.sprachen.isNotEmpty)
            _Zeile('Sprachen laut Anzeige', s.sprachen.map((k) => sprachNamen[k] ?? k).join(', ')),
          if (s.vorschau.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Abschnitt('Auszug'),
            Text(s.vorschau, style: Schrift.body(14, Farben.textHell)),
          ],
          const SizedBox(height: 22),
          HauptKnopf('Anzeige öffnen', symbol: Icons.open_in_new, onTap: () => oeffneLink(context, s.url)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: NebenKnopf(gemerkt ? 'Gemerkt' : 'Merken', gemerkt ? Icons.bookmark : Icons.bookmark_border,
                  aktiv: gemerkt, onTap: () => z.umschaltenGemerkt(s.id)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NebenKnopf(beworben ? 'Beworben' : 'Als beworben markieren', Icons.check_circle_outline,
                  aktiv: beworben, onTap: () => z.umschaltenBeworben(s.id)),
            ),
          ]),
          const SizedBox(height: 10),
          NebenKnopf(ausgeblendet ? 'Wieder anzeigen' : 'Passt nicht – ausblenden', Icons.visibility_off_outlined,
              aktiv: ausgeblendet, onTap: () {
            z.umschaltenAusgeblendet(s.id);
            if (!ausgeblendet) Navigator.of(context).pop();
          }),
        ],
      ),
    );
  }
}

class _Zeile extends StatelessWidget {
  final String links;
  final String rechts;
  const _Zeile(this.links, this.rechts);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(links, style: Schrift.klein(Farben.textGedaempft, 13))),
          Expanded(child: Text(rechts, style: Schrift.body(13.5, Farben.textHell))),
        ]),
      );
}
