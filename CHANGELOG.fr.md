# Changelog

> 🇬🇧 [English version](CHANGELOG.md)

## Non publié

- Correction de `db-import` et de son autocomplétion sur macOS : `mapfile` (bash 4+) et `find -printf` / `date -d` (GNU) sont remplacés par des constructions qui fonctionnent aussi avec le bash 3.2 et les outils BSD fournis par macOS (#7)
- Correction de `db-{prod,preprod}-dump` quand le dossier de dumps distant commence par `~` : le tilde n'était pas développé dans la redirection distante entre guillemets, il passe désormais par `$HOME`, évalué par le shell du serveur (#7)
- README : ne conseiller d'ignorer que le manifeste de l'addon (`.ddev/addon-metadata/drupal-tools/manifest.yaml`) plutôt que tout le dossier `addon-metadata/`, dont les manifestes d'addons de projet ont vocation à être commités (#6)

## 0.1.1 — 2026-07-30

- README : documentation de la mise à jour et de la suppression — toujours depuis le projet qui a servi à l'installation, DDEV enregistrant l'installation par projet (`.ddev/addon-metadata/`, limitation DDEV, cf. ddev/ddev#6145) (#5)
- README : note sur le contexte de projet DDEV exigé par `ddev add-on get` (lancer depuis un dossier de projet ou utiliser `--project`) (#4)
- Changelog basculé en anglais, version française conservée dans `CHANGELOG.fr.md` et liée depuis l'en-tête (#3)
- README principal traduit en anglais, version française conservée dans `README.fr.md` et liée depuis l'en-tête (#2)

## 0.1.0 — 2026-07-29

- Implémentation initiale de l'addon : les 10 commandes globales (`db-import`, `db-export`, `db-{prod,preprod}-{dump,get,import}`, `ssh-{prod,preprod}`) et l'autocomplétion de `db-import`, installées via `global_files`, avec tests bats en HOME isolé (#1)
