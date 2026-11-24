import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

// ---------------------------------------------------------------- Aktionen

Future<void> oeffneLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  var ok = false;
  if (uri != null && uri.hasScheme) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link ließ sich nicht öffnen: $url')));
  }
}

Future<void> anrufen(BuildContext context, String nummer) async {
  final ziffern = nummer.replaceAll(RegExp(r'[^0-9+]'), '');
  if (ziffern.isEmpty) return;
  var ok = false;
  try {
    ok = await launchUrl(Uri(scheme: 'tel', path: ziffern));
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Telefon: $nummer')));
  }
}

String kartenLink(String adresse) =>
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(adresse)}';

// ---------------------------------------------------------------- Bausteine

class Etikett extends StatelessWidget {
  final String text;
  final Color grund;
  final Color farbe;
  final bool fett;
  const Etikett(this.text, {super.key, this.grund = Farben.flaecheHoch, this.farbe = Farben.textMittel, this.fett = true});

  const Etikett.neu(this.text, {super.key})
      : grund = Farben.akzent,
        farbe = Farben.aufAkzent,
        fett = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: grund, borderRadius: BorderRadius.circular(10)),
      child: Text(text,
          style: Schrift.klein(farbe, 12).copyWith(fontWeight: fett ? FontWeight.w700 : FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
    );
  }
}

class Kachel extends StatelessWidget {
  final Widget child;
  final Color farbe;
  final Color rand;
  final EdgeInsetsGeometry innen;
  final double radius;
  final VoidCallback? onTap;
  final bool gestrichelt;
  const Kachel({
    super.key,
    required this.child,
    this.farbe = Farben.flaeche,
    this.rand = Farben.linie,
    this.innen = const EdgeInsets.all(14),
    this.radius = 18,
    this.onTap,
    this.gestrichelt = false,
  });

  @override
  Widget build(BuildContext context) {
    final form = BorderRadius.circular(radius);
    return Material(
      color: farbe,
      shape: RoundedRectangleBorder(
        borderRadius: form,
        side: BorderSide(color: rand, width: gestrichelt ? 1.2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: innen, child: child)),
    );
  }
}

class Abschnitt extends StatelessWidget {
  final String text;
  const Abschnitt(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text.toUpperCase(), style: Schrift.etikett()));
}

class HauptKnopf extends StatelessWidget {
  final String text;
  final IconData? symbol;
  final VoidCallback? onTap;
  const HauptKnopf(this.text, {super.key, this.symbol, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Material(
        color: Farben.akzent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(text, style: Schrift.h2(18, Farben.aufAkzent).copyWith(fontWeight: FontWeight.w700)),
              if (symbol != null) ...[
                const SizedBox(width: 10),
                Icon(symbol, color: Farben.aufAkzent, size: 21),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NebenKnopf extends StatelessWidget {
  final String text;
  final IconData symbol;
  final VoidCallback? onTap;
  final bool aktiv;
  const NebenKnopf(this.text, this.symbol, {super.key, this.onTap, this.aktiv = false});

  @override
  Widget build(BuildContext context) {
    final farbe = aktiv ? Farben.akzent : Farben.text;
    return SizedBox(
      height: 46,
      child: Material(
        color: aktiv ? Farben.akzentFlaeche : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: aktiv ? Farben.akzentRand : Farben.linieHell),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(symbol, size: 18, color: farbe),
              const SizedBox(width: 8),
              Flexible(child: Text(text, style: Schrift.body(14, farbe, FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

class RundKnopf extends StatelessWidget {
  final IconData symbol;
  final String hinweis;
  final VoidCallback? onTap;
  final Color farbe;
  const RundKnopf(this.symbol, this.hinweis, {super.key, this.onTap, this.farbe = Farben.text});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: hinweis,
      child: Material(
        color: Farben.flaeche,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Farben.linieHell)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(symbol, size: 20, color: farbe)),
        ),
      ),
    );
  }
}

/// Farbiger Hinweis (Warnung, Fehler, Info) mit Symbol.
class Hinweis extends StatelessWidget {
  final String text;
  final IconData symbol;
  final Color farbe;
  final Color grund;
  final Color rand;
  final VoidCallback? onTap;
  const Hinweis(this.text,
      {super.key,
      this.symbol = Icons.info_outline,
      this.farbe = Farben.warn,
      this.grund = Farben.warnFlaeche,
      this.rand = Farben.warnRand,
      this.onTap});

  const Hinweis.fehler(this.text, {super.key, this.onTap})
      : symbol = Icons.error_outline,
        farbe = Farben.fehler,
        grund = Farben.fehlerFlaeche,
        rand = const Color(0xFF4A2420);

  @override
  Widget build(BuildContext context) {
    return Kachel(
      farbe: grund,
      rand: rand,
      radius: 16,
      onTap: onTap,
      innen: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(symbol, size: 20, color: farbe),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Schrift.body(13.5, const Color(0xFFE8D9C2)))),
        ],
      ),
    );
  }
}
