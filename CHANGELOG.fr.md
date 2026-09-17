# Changelog

> 🇬🇧 [English version](CHANGELOG.md)

## Non publié

- `db-import` et `db-export` suivent le type DDEV du projet (clé `type` du `.ddev/config.yaml`) : étapes `drush` inchangées pour Drupal, `console cache:clear` après un import pour Symfony, aucune étape automatique pour les autres types, dont les étapes propres se déclarent dans les hooks `post-import-db` de DDEV. Voir l'ADR `0009-commandes-etapes-selon-le-type-ddev` (#9)
- Lecture du `.env.local` avant le `.env` pour toutes les variables du projet (`<ENV>_*`, `LOCAL_DB_PATH`, `DB_DUMP_DIR`) : les projets Symfony versionnent leur `.env` et gardent les valeurs locales dans `.env.local`. Voir l'ADR `0009-config-env-local-avant-env` (#9)
- `db-{prod,preprod}-dump` explique qu'il passe par drush quand `<ENV>_DRUSH` manque sur un projet non Drupal (#9)

## 0.2.0 — 2026-09-17

- Correction de `db-{prod,preprod}-dump` qui sortait en code 2 après un dump réussi : le listage final du dossier de dumps se lançait depuis le home SSH, où un `<ENV>_DB_PATH` relatif n'existe pas. Il se lance désormais depuis `<ENV>_PATH`, comme le dump lui-même (#10)
- Correction de `ddev <commande> -h` qui exécutait les commandes distantes (`db-{prod,preprod}-{dump,get,import}`, `ssh-{prod,preprod}`) au lieu d'afficher leur aide : sans annotation `## Flags:`, DDEV transmettait `-h` au script. Les options inconnues sont désormais refusées, par exemple `ddev db-prod-import -y` (#10)
- `db-{prod,preprod}-get` affiche la date du dump récupéré et avertit s'il a plus de 24 h : un `<ENV>_DB_PATH` qui pointe vers un dossier abandonné ne passe plus inaperçu (#10)

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
