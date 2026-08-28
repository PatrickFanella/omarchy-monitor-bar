# SPDX-License-Identifier: MIT

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
I18N = ROOT / "I18n.js"


def run_js(expression: str):
    source = I18N.read_text(encoding="utf-8").replace(".pragma library", "", 1)
    script = source + "\nconsole.log(JSON.stringify(" + expression + "))\n"
    result = subprocess.run(
        ["node", "-e", script], capture_output=True, text=True, check=True
    )
    return json.loads(result.stdout)


class I18nTest(unittest.TestCase):
    def test_catalogs_are_explicit_and_complete_in_source(self) -> None:
        source = I18N.read_text(encoding="utf-8")
        self.assertNotIn("function complete", source)
        self.assertNotIn("complete(", source)

        locales = ("de", "es", "fr", "it", "pt_BR", "nl", "pl", "hr", "zh_CN")
        english_match = re.search(
            r"var en = \{(.*?)\n\}\n\nvar catalogs", source, re.DOTALL
        )
        self.assertIsNotNone(english_match)
        assert english_match is not None
        blocks = {"en": english_match.group(1)}
        for index, locale in enumerate(locales):
            next_locale = locales[index + 1] if index + 1 < len(locales) else None
            end = rf"\n  \}},\n  {next_locale}: \{{" if next_locale else r"\n  \}\n\}"
            match = re.search(rf"\n  {locale}: \{{(.*?){end}", source, re.DOTALL)
            self.assertIsNotNone(match, locale)
            assert match is not None
            blocks[locale] = match.group(1)

        explicit_keys = {
            locale: re.findall(r'"([^"]+)"\s*:', block)
            for locale, block in blocks.items()
        }
        english_keys = set(explicit_keys["en"])
        self.assertEqual(len(explicit_keys["en"]), 116)
        for locale, keys in explicit_keys.items():
            self.assertEqual(len(keys), 116, locale)
            self.assertEqual(len(set(keys)), 116, f"{locale}: duplicate key")
            self.assertEqual(set(keys), english_keys, locale)

    def test_catalogs_have_identical_keys_and_placeholders(self) -> None:
        data = run_js("catalogs")
        self.assertEqual(
            set(data), {"en", "de", "es", "fr", "it", "pt_BR", "nl", "pl", "hr", "zh_CN"}
        )
        english_keys = set(data["en"])
        placeholder = re.compile(r"\{([A-Za-z][A-Za-z0-9_]*)\}")
        for locale, catalog in data.items():
            self.assertEqual(set(catalog), english_keys, locale)
            for key, message in catalog.items():
                self.assertEqual(
                    set(placeholder.findall(message)),
                    set(placeholder.findall(data["en"][key])),
                    f"{locale}: {key}",
                )

    def test_locale_routing(self) -> None:
        cases = {
            "de-DE": "de", "es_MX": "es", "fr-FR": "fr", "it": "it",
            "pt": "pt_BR", "pt-BR": "pt_BR", "pt_BR": "pt_BR",
            "pt-Latn-BR": "pt_BR", "pt_Latn_BR": "pt_BR", "pt-PT": "en",
            "nl-NL": "nl", "pl_PL": "pl", "hr-HR": "hr",
            "zh": "zh_CN", "zh-CN": "zh_CN", "zh_SG": "zh_CN",
            "zh-Hans": "zh_CN", "zh-Hans-CN": "zh_CN", "zh-TW": "en",
            "zh_HK": "en", "zh-MO": "en", "zh-Hant": "en", "ja-JP": "en",
        }
        for locale, expected in cases.items():
            self.assertEqual(run_js(f"normalizeLocale({json.dumps(locale)})"), expected)
        self.assertEqual(run_js('resolveLocale(["xx", "de-DE"], "fr_FR")'), "de")
        self.assertEqual(
            run_js('resolveLocale({0: "xx", 1: "de-DE", length: 2}, "fr_FR")'),
            "de",
        )
        self.assertEqual(run_js('resolveLocale(["pt-PT", "pt-BR"], "pt_BR")'), "en")
        self.assertEqual(run_js('resolveLocale(["zh-TW", "zh-CN"], "zh_CN")'), "en")

    def test_qt_locale_ui_languages_array_like_sequence(self) -> None:
        qmltestrunner = shutil.which("qmltestrunner")
        if not qmltestrunner:
            self.skipTest("QML test runtime unavailable")

        source = """import QtQuick 2.0
import QtTest 1.0
import "I18n.js" as I18n

TestCase {
    name: "LocaleUiLanguages"

    function test_arrayLikeSequence() {
        var locale = Qt.locale("de_DE")
        console.log("I18N_RESULT:" + JSON.stringify({
            resolved: I18n.resolveLocale(locale.uiLanguages, locale.name),
            length: locale.uiLanguages.length
        }))
    }
}
"""
        path = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w", suffix=".qml", dir=ROOT, encoding="utf-8", delete=False
            ) as qml_file:
                qml_file.write(source)
                path = Path(qml_file.name)
            result = subprocess.run(
                [qmltestrunner, "-input", str(path), "-platform", "offscreen"],
                capture_output=True,
                text=True,
                check=False,
                timeout=15,
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
            )
        finally:
            if path is not None:
                path.unlink(missing_ok=True)

        match = re.search(r"I18N_RESULT:(\{.*\})", result.stdout + result.stderr)
        self.assertIsNotNone(match, result.stdout + result.stderr)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        assert match is not None
        data = json.loads(match.group(1))
        self.assertGreater(data["length"], 0)
        self.assertEqual(data["resolved"], "de")

    def test_fallback_and_interpolation(self) -> None:
        self.assertEqual(run_js('t("ja", "action.save")'), "Save")
        self.assertEqual(run_js('t("de", "missing.message")'), "missing.message")
        self.assertEqual(
            run_js('t("en", "monitor.namedMode", {name: "DP-1", mode: "Full"})'),
            "DP-1 · Full",
        )
        self.assertEqual(
            run_js('t("en", "monitor.namedMode", {name: "DP-1"})'),
            "DP-1 · {mode}",
        )

    def test_reviewed_translation_corrections(self) -> None:
        data = run_js("catalogs")
        reload_before_save = {
            "es": "Recargue la configuración o rebase este borrador",
            "fr": "Rechargez la configuration ou rebasez ce brouillon",
            "it": "Ricarica la configurazione o ribasa questa bozza",
            "nl": "Herlaad de configuratie of herbaseer dit concept",
        }
        for locale, text in reload_before_save.items():
            self.assertIn(text, data[locale]["conflict.reloadBeforeSave"])

        self.assertEqual(data["hr"]["action.rebase"], "Ponovno primijeni skicu")
        self.assertEqual(data["hr"]["appearance.transparent"], "Prozirna")
        self.assertNotIn("presloži", " ".join(data["hr"].values()).lower())
        self.assertEqual(data["zh_CN"]["monitor.hiddenNew"], "{name} · 隐藏 / 未配置")
        for locale in ("pl", "hr"):
            self.assertIn(
                data[locale]["action.restartNow"],
                data[locale]["restart.keyboardHelp"],
            )
        self.assertEqual(
            [data["de"][key] for key in ("mode.full", "mode.minimal", "mode.hidden")],
            ["Voll", "Minimal", "Ausgeblendet"],
        )
        self.assertEqual(data["de"]["monitor.primaryFull"], "{name} · PRIMÄR / VOLL")

    def test_qml_uses_runtime_i18n(self) -> None:
        known_literals = (
            "Multi-Monitor Bar settings", "Save changes before closing?", "Workspace ",
            "Occupied workspace on ", "Open Multi-Monitor Bar settings", "Bar position",
        )
        for name in ("SettingsPanel.qml", "SettingsButton.qml", "Workspaces.qml"):
            source = (ROOT / name).read_text(encoding="utf-8")
            self.assertIn('import "I18n.js" as I18n', source)
            self.assertIn("property string locale: I18n.currentLocale()", source)
            self.assertIn("I18n.t(", source)
            for literal in known_literals:
                self.assertNotIn(f'"{literal}', source, f"{name}: {literal}")


if __name__ == "__main__":
    unittest.main()
