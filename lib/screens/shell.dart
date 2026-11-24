import 'package:flutter/material.dart';

import '../daten.dart';
import '../push.dart';
import '../theme.dart';
import 'einstellungen_seite.dart';
import 'merkliste_seite.dart';
import 'stellen_seite.dart';

/// Rahmen mit den drei Reitern unten: Stellen, Merkliste, Einstellungen.
class Hauptrahmen extends StatelessWidget {
  final Push? push;
  const Hauptrahmen({super.key, this.push});

  @override
  Widget build(BuildContext context) {
    final z = Zustand.von(context);
    return ValueListenableBuilder<int>(
      valueListenable: z.reiter,
      builder: (context, reiter, _) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: reiter,
            children: [
              StellenSeite(zuEinstellungen: () => z.reiter.value = 2),
              const MerklisteSeite(),
              EinstellungenSeite(push: push),
            ],
          ),
        ),
        bottomNavigationBar: _Leiste(
          aktiv: reiter,
          zahlen: [z.neuAnzahl, z.merkliste.length, 0],
          waehle: (i) => z.reiter.value = i,
        ),
      ),
    );
  }
}

class _Leiste extends StatelessWidget {
  final int aktiv;
  final List<int> zahlen;
  final ValueChanged<int> waehle;
  const _Leiste({required this.aktiv, required this.zahlen, required this.waehle});

  @override
  Widget build(BuildContext context) {
    const eintraege = [
      (Icons.engineering, 'Stellen'),
      (Icons.bookmark_border, 'Merkliste'),
      (Icons.tune, 'Einstellungen'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Farben.leiste,
        border: Border(top: BorderSide(color: Color(0xFF1A232D))),
      ),
      padding: EdgeInsets.fromLTRB(8, 6, 8, 8 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          for (var i = 0; i < eintraege.length; i++)
            Expanded(
              child: Semantics(
                selected: i == aktiv,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => waehle(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Badge(
                          isLabelVisible: zahlen[i] > 0,
                          backgroundColor: i == 0 ? Farben.akzent : Farben.flaecheHoch,
                          textColor: i == 0 ? Farben.aufAkzent : Farben.textHell,
                          label: Text('${zahlen[i]}'),
                          child: Icon(eintraege[i].$1,
                              size: 23, color: i == aktiv ? Farben.akzent : Farben.textGedaempft),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          eintraege[i].$2,
                          maxLines: 1,
                          style: Schrift.klein(i == aktiv ? Farben.akzent : Farben.textGedaempft, 12)
                              .copyWith(fontWeight: i == aktiv ? FontWeight.w700 : FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
