# ddev-drupal-tools

Addon [DDEV](https://ddev.com/) **global** pour projets Drupal : gestion des dumps de base de
données en local et rapatriement depuis les serveurs de production / pré-production.

Les commandes sont installées dans le dossier DDEV global (`~/.ddev/commands/host/`) et sont
donc disponibles dans **tous** les projets DDEV de la machine.

Présentation détaillée sur kgaut.net :

- [db-import / db-export : deux commandes DDEV globales pour gérer ses dumps](https://kgaut.net/blog/2026/db-import-db-export-deux-commandes-ddev-globales-pour-gerer-ses-dumps)
- [db-prod-* et ssh-prod : des commandes DDEV globales pour rapatrier sa base de production](https://kgaut.net/blog/2026/db-prod-et-ssh-prod-des-commandes-ddev-globales-pour-rapatrier-sa-base-de-production)

## Installation

```bash
ddev add-on get kgaut/ddev-drupal-tools
```

Ou depuis un clone local :

```bash
ddev add-on get /chemin/vers/ddev-drupal-tools
```

Suppression : `ddev add-on remove drupal-tools`.

## Commandes

### Locales

| Commande | Description |
| --- | --- |
| `ddev db-import [dump]` | Vide la base, importe un dump (le plus récent du dossier de dumps par défaut), puis `drush deploy`, `drush cr`, `drush uli`. Options : `-l` (lister les dumps), `-n` (dry-run), `-y` (sans confirmation). |
| `ddev db-export` | Vide les caches puis exporte la base vers `<dossier>/<date>-<projet>-dev.sql.gz`. Options : `--no-gzip`, `--no-cr`, `-n`. |

Formats gérés par `db-import` : `.sql`, `.sql.gz`, `.sql.bz2`, `.sql.xz`, `.mysql`, `.mysql.gz`, `.zip`, `.tgz`, `.tar.gz`.
Le nom de dump s'autocomplète (`ddev db-import <tab>`), du plus récent au plus ancien.

### Serveur distant (production / pré-production)

| Commande | Description |
| --- | --- |
| `ddev db-prod-dump` | `drush sql-dump --gzip` sur le serveur, fichier horodaté dans `PROD_DB_PATH` (le dump reste sur le serveur). |
| `ddev db-prod-get` | Rapatrie le dump distant le plus récent dans le dossier de dumps local. |
| `ddev db-prod-import` | Enchaîne `db-prod-get` + `db-import`. |
| `ddev ssh-prod` | Session SSH sur le serveur de production du projet courant. |

Chaque commande a sa jumelle `preprod` : `db-preprod-dump`, `db-preprod-get`,
`db-preprod-import`, `ssh-preprod` — mêmes fichiers, préfixe de variables `PREPROD_`.

## Configuration

Tout se configure dans le `.env` à la racine de chaque projet (jamais sourcé : les variables
sont extraites par `grep`). Les commandes sont visibles partout mais ne servent que dans les
projets configurés — une variable manquante donne une erreur explicite.

```bash
# .env du projet
PROD_USER=kevin
PROD_HOST=mon-serveur.example.org
PROD_PORT=22                           # optionnel, défaut 22
PROD_PATH=/var/www/monprojet           # racine du projet sur le serveur
PROD_DRUSH=vendor/bin/drush            # binaire drush, relatif à PROD_PATH
PROD_DB_PATH=/var/www/monprojet/dumps  # dossier des dumps, sur le serveur
PROD_URL=monprojet.example.org         # sert à nommer les fichiers de dump

# même principe pour la préprod, préfixe PREPROD_
```

### Dossier de dumps local

Commun à toutes les commandes. Défaut `files/dumps` (relatif à la racine du projet),
surchargeable via `DB_DUMP_DIR` (`.env` du projet, puis `.ddev/.env`), en chemin relatif ou
absolu. Les commandes `db-{prod,preprod}-get` acceptent en plus `LOCAL_DB_PATH`, prioritaire
sur `DB_DUMP_DIR`.

## Tests

```bash
bats tests
```

Les tests utilisent un `HOME` isolé : ils ne touchent pas au `~/.ddev` de la machine.

## Licence

MIT.
