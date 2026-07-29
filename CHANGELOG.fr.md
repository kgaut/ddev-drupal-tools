# Changelog

> 🇬🇧 [English version](CHANGELOG.md)

## Non publié

- README : note sur le contexte de projet DDEV exigé par `ddev add-on get` (lancer depuis un dossier de projet ou utiliser `--project`) (#4)
- Changelog basculé en anglais, version française conservée dans `CHANGELOG.fr.md` et liée depuis l'en-tête (#3)
- README principal traduit en anglais, version française conservée dans `README.fr.md` et liée depuis l'en-tête (#2)

## 0.1.0 — 2026-07-29

- Implémentation initiale de l'addon : les 10 commandes globales (`db-import`, `db-export`, `db-{prod,preprod}-{dump,get,import}`, `ssh-{prod,preprod}`) et l'autocomplétion de `db-import`, installées via `global_files`, avec tests bats en HOME isolé (#1)
