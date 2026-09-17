# 0001 — La configuration des projets se lit dans leur `.env`, sans jamais le sourcer

- **Statut** : Amendée par `0009-config-env-local-avant-env`
- **Date** : 29/07/2026
- **Ticket** : #1
- **Périmètre** : config
- **Remplace** : —
- **Amende** : —

## Contexte

Les commandes venaient des dotfiles de Kevin. Elles ont été reprises à l'identique dans l'addon
lors de #1, le 29/07/2026. Un `.env` de projet peut contenir n'importe quoi : le sourcer
exécuterait son contenu.

## Décision

- Les variables `<ENV>_*` et `LOCAL_DB_PATH` se lisent dans le `.env` à la racine du projet. Une
  variable d'environnement prend le pas.
- `DB_DUMP_DIR` se lit dans le `.env`, puis dans `.ddev/.env`, avec `files/dumps` par défaut.
- Le fichier n'est **jamais sourcé** : chaque variable est extraite par `grep` (helper
  `read_env_var`), dupliqué dans chaque commande, car un `_lib.sh` partagé apparaîtrait comme
  commande dans `ddev -h`.

## Options écartées

- **Sourcer le `.env`** : cela exécuterait son contenu.

## Conséquences

- Aucune variable de projet n'est lue ailleurs que dans ces fichiers.

## Suivi

- **29/07/2026** : décision prise lors de l'empaquetage de #1. Le principe « jamais sourcé » est
  documenté dans le README et dans le CLAUDE.md du dépôt.
- **17/09/2026** : ADR écrite après coup dans #9, parce que `0009-config-env-local-avant-env`
  l'amende (lecture de `.env.local` avant `.env`). Elle est archivée dans le même commit.
