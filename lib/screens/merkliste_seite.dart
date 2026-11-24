import 'package:flutter/material.dart';

import '../daten.dart';
import '../theme.dart';
import '../widgets/bausteine.dart';
import '../widgets/stellen_karte.dart';

/// Gemerkte und beworbene Stellen. Bleiben auf dem Handy gespeichert.
class MerklisteSeite extends StatelessWidget {
  const MerklisteSeite({super.key});

  @override
  Widget build(BuildContext context) {
    final z = Zustand.von(context);
    final liste = z.merkliste;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text('Merkliste', style: Schrift.h1(25)),
        ),
        if (liste.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Tippe bei einer Stelle auf das Lesezeichen oder „Als beworben markieren“. '
              'Sie erscheint dann hier.',
              style: Schrift.body(14, Farben.textMittel),
            ),
          ),
        for (final s in liste) ...[
          StellenKarte(s),
          const SizedBox(height: 10),
        ],
        if (z.ausgeblendet.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Abschnitt('Ausgeblendet'),
          Text('${z.ausgeblendet.length} Stellen ausgeblendet. Zum Zurückholen die Stelle öffnen.',
              style: Schrift.klein(Farben.textGedaempft, 13)),
          const SizedBox(height: 8),
          for (final id in z.ausgeblendet)
            if (z.stelleNachId(id) case final s?) ...[
              StellenKarte(s),
              const SizedBox(height: 10),
            ],
        ],
      ],
    );
  }
}
