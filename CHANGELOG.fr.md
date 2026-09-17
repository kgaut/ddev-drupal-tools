# Changelog

> 🇬🇧 [English version](CHANGELOG.md)

## Non publié

- Correction de `db-{prod,preprod}-dump` qui sortait en code 2 après un dump réussi : le listage final du dossier de dumps se lançait depuis le home SSH, où un `<ENV>_DB_PATH` relatif n'existe pas. Il se lance désormais depuis `<ENV>_PATH`, comme le dump lui-même (#10)

## 0.1.3 — 2026-08-31

- Correction de `db-{prod,preprod}-get` qui cherchait les dumps dans le mauvais dossier distant : un `<ENV>_DB_PATH` relatif était résolu depuis le home SSH, alors que `db-{prod,preprod}-dump` le résout depuis `<ENV>_PATH` — les dumps étaient donc écrits dans un dossier et cherchés dans un autre. Les deux commandes s'accordent désormais, et `<ENV>_PATH` devient une variable requise pour `db-*-get` (#8)

## 0.1.2 — 2026-08-06

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
