# 0001 — Les commandes de base de données enchaînent toujours drush

- **Statut** : Remplacée par `0009-commandes-etapes-selon-le-type-ddev`
- **Date** : 29/07/2026
- **Ticket** : #1
- **Périmètre** : commandes
- **Remplace** : —
- **Amende** : —

## Contexte

Les commandes venaient des dotfiles de Kevin, écrites pour ses projets Drupal. Elles ont été
reprises à l'identique dans l'addon lors de #1, le 29/07/2026. Le nom de l'addon, `drupal-tools`,
en porte la trace.

## Décision

- `db-import` enchaîne, après `ddev import-db`, `ddev drush deploy`, `ddev drush cr` et
  `ddev drush uli`.
- `db-export` lance `ddev drush cr` avant l'export, sauf avec `--no-cr`.
- `db-{prod,preprod}-dump` passe par `<ENV>_DRUSH sql-dump`.
- L'addon s'adresse aux projets Drupal : aucun autre type de projet n'est pris en compte.

## Options écartées

Aucune n'a été consignée : les commandes ont été reprises telles quelles.

## Conséquences

- Hors Drupal, `db-import` et `db-export` échouent après l'import, ou avant l'export (sauf avec
  `--no-cr`).

## Suivi

- **29/07/2026** : décision prise de fait, lors de l'empaquetage de #1.
- **17/09/2026** : ADR écrite après coup dans #9, parce que la décision est renversée par
  `0009-commandes-etapes-selon-le-type-ddev`. Elle est archivée dans le même commit.
