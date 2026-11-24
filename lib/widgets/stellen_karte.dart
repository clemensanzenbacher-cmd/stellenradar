import 'package:flutter/material.dart';

import '../daten.dart';
import '../modelle.dart';
import '../screens/stelle_blatt.dart';
import '../theme.dart';
import 'bausteine.dart';

const laenderNamen = {'CH': 'Schweiz', 'LI': 'Liechtenstein', 'DE': 'Deutschland', 'AT': 'Österreich'};
const sprachNamen = {'de': 'Deutsch', 'en': 'Englisch', 'fr': 'Französisch'};

/// Kleine Etiketten zu Sprache und Englisch-Anforderung.
List<Widget> sprachEtiketten(Stelle s) => [
      if (s.sprache == 'de' && s.englischPflicht != true)
        const Etikett('Deutsch', grund: Farben.akzentFlaeche, farbe: Farben.akzentHell)
      else
        Etikett('Anzeige ${sprachNamen[s.sprache] ?? s.sprache}', grund: Farben.warnTag, farbe: Farben.warnHell),
      if (s.englischPflicht == true) const Etikett('Englisch verlangt', grund: Farben.warnTag, farbe: Farben.warnHell),
    ];

class StellenKarte extends StatelessWidget {
  final Stelle stelle;
  const StellenKarte(this.stelle, {super.key});

  @override
  Widget build(BuildContext context) {
    final z = Zustand.von(context);
    final s = stelle;
    final neu = z.istNeu(s);
    final gemerkt = z.gemerkt.contains(s.id);
    final beworben = z.beworben.contains(s.id);
    return Kachel(
      rand: neu ? Farben.akzentRand : Farben.linie,
      onTap: () => zeigeStelle(context, s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.firma.isEmpty ? s.quelle : s.firma,
                        style: Schrift.klein(Farben.textMittel, 13).copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(s.titel, style: Schrift.h2(16.5), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                tooltip: gemerkt ? 'Nicht mehr merken' : 'Merken',
                visualDensity: VisualDensity.compact,
                onPressed: () => z.umschaltenGemerkt(s.id),
                icon: Icon(gemerkt ? Icons.bookmark : Icons.bookmark_border,
                    color: gemerkt ? Farben.akzent : Farben.textGedaempft),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 15, color: Farben.textGedaempft),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [s.ortText, 'gefunden ${vorZeit(s.ersterfasst, z.jetzt())}'].where((t) => t.isNotEmpty).join(' · '),
                  style: Schrift.klein(Farben.textGedaempft, 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (neu) const Etikett.neu('NEU'),
              if (beworben) const Etikett('beworben', grund: Farben.flaecheHoch, farbe: Farben.info),
              if (!s.aktiv) const Etikett('nicht mehr online', grund: Farben.fehlerFlaeche, farbe: Farben.fehler),
              ...sprachEtiketten(s),
            ],
          ),
        ],
      ),
    );
  }
}
