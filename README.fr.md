# ddev-drupal-tools

> 🇬🇧 [English version](README.md)

Addon [DDEV](https://ddev.com/) **global** pour projets Drupal : gestion des dumps de base de
données en local et rapatriement depuis les serveurs de production / pré-production. Les
commandes locales conviennent aussi aux projets Symfony et aux autres types de projet (voir
[Types de projet](#types-de-projet)).

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

> **Note :** même si l'addon installe ses fichiers globalement, `ddev add-on get` doit
> s'exécuter dans le contexte d'un projet DDEV : lancer la commande depuis un dossier de
> projet, ou ajouter `--project <nom>`. Hors projet, elle échoue avec
> « could not find a project ».

DDEV n'a pas de vraie notion d'« addon global » (feature request ouverte :
[ddev/ddev#6145](https://github.com/ddev/ddev/issues/6145)) : `global_files` ne contrôle
que la destination des **fichiers** copiés, tandis que l'installation elle-même (nom,
version, liste des fichiers) est enregistrée **dans le projet** utilisé comme contexte,
dans `.ddev/addon-metadata/drupal-tools/manifest.yaml`. Ne pas supprimer ce fichier —
DDEV en a besoin pour la mise à jour et la suppression — mais le garder hors du dépôt en
ignorant `.ddev/addon-metadata/drupal-tools/manifest.yaml` dans le `.gitignore` racine du
projet (ignorer ce seul fichier, pas tout le dossier `addon-metadata/` : les manifestes des
addons de projet ont vocation à être commités).

### Mise à jour

Relancer la commande d'installation **depuis le projet qui a servi à installer l'addon**
(c'est là que DDEV a enregistré l'installation) :

```bash
ddev add-on get kgaut/ddev-drupal-tools
```

Les fichiers portant le marqueur `#ddev-generated` sont remplacés par la nouvelle version.
Lancer la commande depuis un autre projet fonctionne aussi, mais laisse un second manifeste
dans ce projet — mieux vaut toujours s'ancrer sur le même.

### Suppression

Depuis le même projet :

```bash
ddev add-on remove drupal-tools
```

À cause du suivi par projet décrit ci-dessus, `ddev add-on remove` et
`ddev add-on list --installed` ne voient l'addon que depuis le projet qui détient le
manifeste.

## Commandes

### Locales

| Commande | Description |
| --- | --- |
| `ddev db-import [dump]` | Vide la base, importe un dump (le plus récent du dossier de dumps par défaut), puis lance les étapes du type de projet (Drupal : `drush deploy`, `drush cr`, `drush uli`). Options : `-l` (lister les dumps), `-n` (dry-run), `-y` (sans confirmation). |
| `ddev db-export` | Exporte la base vers `<dossier>/<date>-<projet>-dev.sql.gz`, après vidage des caches pour un projet Drupal. Options : `--no-gzip`, `--no-cr`, `-n`. |

Formats gérés par `db-import` : `.sql`, `.sql.gz`, `.sql.bz2`, `.sql.xz`, `.mysql`, `.mysql.gz`, `.zip`, `.tgz`, `.tar.gz`.
Le nom de dump s'autocomplète (`ddev db-import <tab>`), du plus récent au plus ancien.

### Types de projet

Les étapes qui entourent un import ou un export suivent le type DDEV du projet (clé `type` du
`.ddev/config.yaml`), de la même façon que DDEV ne fournit `ddev drush` qu'aux projets Drupal
et `ddev console` qu'aux projets Symfony :

| Type DDEV | `db-import`, après l'import | `db-export`, avant l'export |
| --- | --- | --- |
| `drupal`, `drupal6` … `drupal12` | `drush deploy`, `drush cr`, `drush uli` | `drush cr` (`--no-cr` pour s'en passer) |
| `symfony` | `console cache:clear` | — |
| autre type | — | — |

Les étapes propres à un projet se déclarent dans les hooks de DDEV, que `ddev import-db`
(utilisé par `db-import`) déclenche de toute façon :

```yaml
# .ddev/config.yaml
hooks:
  post-import-db:
    - exec: wp cache flush   # par exemple, un projet WordPress
```

`db-{prod,preprod}-dump` passe par `drush sql-dump` sur le serveur : il ne sert qu'aux projets
Drupal.

### Serveur distant (production / pré-production)

| Commande | Description |
| --- | --- |
| `ddev db-prod-dump` | `drush sql-dump --gzip` sur le serveur, fichier horodaté dans `PROD_DB_PATH` (le dump reste sur le serveur). Drupal uniquement. |
| `ddev db-prod-get` | Rapatrie le dump distant le plus récent dans le dossier de dumps local, affiche sa date et avertit s'il a plus de 24 h. |
| `ddev db-prod-import` | Enchaîne `db-prod-get` + `db-import`. |
| `ddev ssh-prod` | Session SSH sur le serveur de production du projet courant. |

Chaque commande a sa jumelle `preprod` : `db-preprod-dump`, `db-preprod-get`,
`db-preprod-import`, `ssh-preprod` — mêmes fichiers, préfixe de variables `PREPROD_`.

Chaque commande affiche son aide avec `ddev <commande> -h`, sans rien exécuter.

## Configuration

Tout se configure dans le `.env.local` ou le `.env` à la racine de chaque projet (jamais
sourcés : les variables sont extraites par `grep`). Le `.env.local` passe en premier : les
projets Symfony versionnent leur `.env` et gardent les valeurs locales, comme les accès
serveur, dans `.env.local`. Les commandes sont visibles partout mais ne servent que dans les
projets configurés — une variable manquante donne une erreur explicite.

```bash
# .env.local (ou .env) du projet
PROD_USER=kevin
PROD_HOST=mon-serveur.example.org
PROD_PORT=22                           # optionnel, défaut 22
PROD_PATH=/var/www/monprojet           # racine du projet sur le serveur
PROD_DRUSH=vendor/bin/drush            # binaire drush, relatif à PROD_PATH
PROD_DB_PATH=dumps                     # dossier des dumps, relatif à PROD_PATH
PROD_URL=monprojet.example.org         # sert à nommer les fichiers de dump

# même principe pour la préprod, préfixe PREPROD_
```

Comme `PROD_DRUSH`, un `PROD_DB_PATH` relatif est résolu depuis `PROD_PATH`. Les chemins
absolus et ceux commençant par `~` sont utilisés tels quels.

### Dossier de dumps local

Commun à toutes les commandes. Défaut `files/dumps` (relatif à la racine du projet),
surchargeable via `DB_DUMP_DIR` (`.env.local` du projet, puis `.env`, puis `.ddev/.env`), en
chemin relatif ou absolu. Les commandes `db-{prod,preprod}-get` acceptent en plus `LOCAL_DB_PATH`, prioritaire
sur `DB_DUMP_DIR`.

## Tests

```bash
bats tests
```

Les tests utilisent un `HOME` isolé : ils ne touchent pas au `~/.ddev` de la machine.

## Licence

MIT.
