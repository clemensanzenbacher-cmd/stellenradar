import 'package:flutter/material.dart';

import '../daten.dart';
import '../modelle.dart';
import '../push.dart';
import '../theme.dart';
import '../widgets/bausteine.dart';

class EinstellungenSeite extends StatefulWidget {
  final Push? push;
  const EinstellungenSeite({super.key, this.push});

  @override
  State<EinstellungenSeite> createState() => _EinstellungenSeiteState();
}

class _EinstellungenSeiteState extends State<EinstellungenSeite> {
  bool? _erlaubt;

  @override
  void initState() {
    super.initState();
    _pruefe();
  }

  Future<void> _pruefe() async {
    final p = widget.push;
    if (p == null) return;
    final ok = await p.erlaubt();
    if (mounted) setState(() => _erlaubt = ok);
  }

  @override
  Widget build(BuildContext context) {
    final z = Zustand.von(context);
    final letzter = z.daten.letzterLauf;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Text('Einstellungen', style: Schrift.h1(25)),
        ),
        const Abschnitt('Benachrichtigungen'),
        if (_erlaubt == false)
          Hinweis('Benachrichtigungen sind aus. Tippe hier, um sie zu erlauben.', onTap: () async {
            await widget.push?.erneutAnfragen();
            await _pruefe();
          })
        else
          Hinweis(
            'Push ist an. Bei neuen Stellen kommt eine Meldung (ab 4 neuen auf einmal eine Sammelmeldung).',
            symbol: Icons.notifications_active_outlined,
            farbe: Farben.akzent,
            grund: Farben.akzentFlaeche,
            rand: Farben.akzentRand,
          ),
        const SizedBox(height: 20),
        const Abschnitt('Filter'),
        Kachel(
          innen: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Nur deutsche Anzeigen', style: Schrift.body(15)),
            subtitle: Text('Blendet englische/französische Anzeigen und solche mit Pflicht-Englisch aus.',
                style: Schrift.klein()),
            value: z.nurDeutsch,
            onChanged: z.setzeNurDeutsch,
          ),
        ),
        const SizedBox(height: 20),
        const Abschnitt('Wächter'),
        Kachel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                letzter == null ? 'Noch kein Lauf' : 'Letzter Lauf ${vorZeit(letzter, z.jetzt())} (${datumText(letzter)})',
                style: Schrift.body(14.5),
              ),
              const SizedBox(height: 4),
              Text('Läuft alle 2 Stunden in GitHub Actions, ganz ohne KI-Kosten.', style: Schrift.klein()),
              const SizedBox(height: 12),
              for (final q in z.daten.quellen)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(q.ok ? Icons.check_circle : Icons.error_outline,
                        size: 16, color: q.ok ? Farben.akzent : Farben.fehler),
                    const SizedBox(width: 8),
                    Expanded(child: Text(q.name, style: Schrift.body(13.5))),
                    Text('${q.passend} passend', style: Schrift.klein(Farben.textGedaempft, 12.5)),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Gesucht wird: Praktikum, Internship, Trainee, Young Talent, Graduate – nur mit Maschinenbau-Bezug '
          '(Konstruktion, Entwicklung, Produktion, Qualität, Test, Simulation, Luft- und Raumfahrt …). '
          'Neue Stellen werden erst gemeldet, wenn ihr Link geprüft funktioniert.',
          style: Schrift.klein(Farben.textGedaempft, 12.5),
        ),
      ],
    );
  }
}
