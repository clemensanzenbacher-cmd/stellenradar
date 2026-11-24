import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import waechter as w  # noqa: E402


class FilterTest(unittest.TestCase):
    def test_passende(self):
        for titel in ["Praktikum im Bereich Konstruktion (m/w/d)",
                      "Intern Materials & Processes Engineer (all genders)",
                      "Young Talent - Simulation (m/f/x)",
                      "Global Engineering Excellence Graduate Trainee (f/m/d)",
                      "Hochschulpraktikant/-in Projekt EIGER: Drohnen und Robotik",
                      "Stagiaire Ingénieur génie industriel ou de production (H/F/D) 100%"]:
            self.assertTrue(w.passt(titel)[0], titel)

    def test_unpassende(self):
        for titel in ["Praktikant (m/w/d) Human Resources",
                      "Schülerpraktikant Elektroniker (mwd)",
                      "Werkstudent Konstruktion (m/w/d)",
                      "Senior Mechanical Engineer",
                      "Internship – Data Engineer - Optimization of Data Delivery",
                      "Praktikant:in Administration 80-100%",
                      "Stagiaire MPC 3+1",
                      "Praktikant Bauingenieurwesen 4-6 Monate",
                      "Praktikant:in SRF Bounce",
                      "Praktikant:in Gebäudetechnik 80-100% (6-12 Monate)",
                      "Hochschulpraktikant/-in Projekt EIGER: Drohnen, Drohnenabwehr und Robotik",
                      "Praktikum 3D CAD Planer:in",
                      "Praktikum Elektrotechnik (m/w/d)",
                      "Praktikum Einkauf Maschinenbau"]:
            self.assertFalse(w.passt(titel)[0], titel)

    def test_volltext(self):
        # Politikwissenschaft in der Beschreibung: raus
        self.assertFalse(w.passt_volltext(
            "Praktikum Projektentwicklung (m/w/d)",
            "Du studierst Politikwissenschaften oder Sozialwissenschaften und interessierst dich für Projekte.")[0])
        # Maschinenbau in der Beschreibung: drin
        self.assertTrue(w.passt_volltext(
            "Praktikum Entwicklung (m/w/d)",
            "Studium Maschinenbau oder Mechatronik, erste Erfahrung mit SolidWorks oder CATIA.")[0])
        # Gemischte Studienrichtungen mit klarem Ingenieurbezug: drin
        self.assertTrue(w.passt_volltext(
            "Trainee Produktion",
            "Studium Maschinenbau, Wirtschaftsingenieurwesen oder Betriebswirtschaft.")[0])
        # Beschreibung ohne jeden Maschinenbau-Bezug: raus
        self.assertFalse(w.passt_volltext("Praktikum Qualität", "Du unterstützt unser Team im Alltag.")[0])
        # Fremdes Fach im Titel lässt sich nicht durch die Beschreibung retten
        self.assertFalse(w.passt("AI Agent Builder Graduate Opportunity", "Simulation of agents")[0])

    def test_gesamt(self):
        def gesamt(titel, text="", kat=None):
            return w.passt(titel, text, kat)[0] and w.passt_volltext(titel, text, kat)[0]
        self.assertTrue(gesamt("Praktikum im Bereich Konstruktion (m/w/d)"))
        self.assertTrue(gesamt("Young Talent - Simulation (m/f/x)"))
        self.assertTrue(gesamt("Praktikum Maschinenbau (m/w/d)"))
        self.assertFalse(gesamt("Technische:r Praktikant:in"))
        self.assertFalse(gesamt("Internship – Data Engineer"))
        # ohne Maschinenbau-Studium im Text: raus, mit: drin
        titel = "Intern Materials & Processes Engineer (all genders)"
        self.assertFalse(gesamt(titel, "Du unterstützt unser Team bei spannenden Projekten. " * 10))
        self.assertTrue(gesamt(titel, "Du studierst Maschinenbau, Werkstofftechnik oder Aerospace."))
        self.assertFalse(gesamt(titel, "Du studierst Politikwissenschaften. " * 5))
        # jobs.ch-Kategorie Maschinenbau zählt
        self.assertTrue(gesamt("Praktikum Forschungsprojekt (m/w/d)", "", [98, 109, 199]))
        self.assertFalse(gesamt("Praktikum Forschungsprojekt (m/w/d)", "", [97, 100, 121]))

    def test_sprache(self):
        self.assertEqual(w.sprache("Praktikum im Bereich Konstruktion (m/w/d)"), "de")
        self.assertEqual(w.sprache("Intern Materials & Processes Engineer"), "en")

    def test_sf_titel(self):
        self.assertEqual(w._sf_titel_ort("Praktikum Logistik (Rostock, DE)"), ("Praktikum Logistik", "Rostock", "DE"))
        self.assertEqual(w._sf_titel_ort("Praktikum X (Dachau, BY, DE)")[2], "DE")

    def test_rss(self):
        xml = ("<rss><channel><item><title><![CDATA[Praktikum Konstruktion (m/w/d) (Ehingen, DE)]]></title>"
               "<description><![CDATA[<p>Text</p>]]></description>"
               "<link>https://careers.liebherr.com/job/Ehingen-Praktikum/1234567/?feedId=null</link>"
               "<pubDate>Tue, 24 Nov 2026 2:00:00 GMT</pubDate></item></channel></rss>")
        st = w.parse_sf_rss(xml, {"id": "liebherr", "firma": "Liebherr", "host": "careers.liebherr.com"})
        self.assertEqual(len(st), 1)
        self.assertEqual(st[0].id, "sf-liebherr-1234567")
        self.assertEqual(st[0].url, "https://careers.liebherr.com/job/Ehingen-Praktikum/1234567/")
        self.assertEqual(st[0].land, "DE")


if __name__ == "__main__":
    unittest.main()
