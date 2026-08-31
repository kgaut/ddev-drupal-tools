#!/usr/bin/env bats

# Tests de l'addon drupal-tools. Aucun serveur SSH ni conteneur n'est requis :
# tout se joue sur la copie des commandes globales et leur comportement à vide.
#
# Chaque test tourne avec un HOME isolé (le ~/.ddev réel n'est jamais touché).

COMMANDS=(db-import db-export
  db-prod-dump db-prod-get db-prod-import ssh-prod
  db-preprod-dump db-preprod-get db-preprod-import ssh-preprod)

setup() {
  set -eu -o pipefail
  export ADDON_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export TESTDIR="$(mktemp -d)"
  export HOME="$TESTDIR/home"
  mkdir -p "$HOME"
  export PROJDIR="$TESTDIR/proj"
  mkdir -p "$PROJDIR"
  cd "$PROJDIR"
  ddev config --project-name=test-drupal-tools --project-type=php --auto >/dev/null 2>&1
}

teardown() {
  cd /
  [ -n "${TESTDIR:-}" ] && rm -rf "$TESTDIR"
}

# Stubs ssh/scp : le ssh renvoie un nom de dump fixe (ce que ferait le « ls -t »
# distant) et le scp se contente d'afficher ses arguments, dont la source
# distante — c'est là qu'on lit le chemin résolu.
stub_ssh_scp() {
  mkdir -p "$TESTDIR/bin"
  cat > "$TESTDIR/bin/ssh" <<'STUB'
#!/usr/bin/env bash
echo "dump.sql.gz"
STUB
  cat > "$TESTDIR/bin/scp" <<'STUB'
#!/usr/bin/env bash
echo "scp $*"
STUB
  chmod +x "$TESTDIR/bin/ssh" "$TESTDIR/bin/scp"
}

install_addon() {
  run ddev add-on get "$ADDON_DIR"
  [ "$status" -eq 0 ]
}

@test "install : les commandes sont copiées dans le ~/.ddev global et exécutables" {
  install_addon
  for c in "${COMMANDS[@]}"; do
    [ -x "$HOME/.ddev/commands/host/$c" ]
  done
  [ -x "$HOME/.ddev/commands/host/autocomplete/db-import" ]
}

@test "les commandes apparaissent dans ddev -h" {
  install_addon
  run ddev -h
  [ "$status" -eq 0 ]
  for c in "${COMMANDS[@]}"; do
    [[ "$output" == *"$c"* ]]
  done
}

@test "db-prod-dump échoue explicitement quand les variables PROD_* manquent" {
  install_addon
  run ddev db-prod-dump
  [ "$status" -ne 0 ]
  [[ "$output" == *"manquant"* ]]
}

@test "db-preprod-get échoue explicitement quand les variables PREPROD_* manquent" {
  install_addon
  run ddev db-preprod-get
  [ "$status" -ne 0 ]
  [[ "$output" == *"manquant"* ]]
}

@test "db-import -l liste les dumps de DB_DUMP_DIR, du plus récent au plus ancien" {
  install_addon
  echo "DB_DUMP_DIR=dumps" > .env
  mkdir -p dumps
  # « touch -t » (POSIX) plutôt que « touch -d » (GNU) : les tests doivent
  # pouvoir tourner sur macOS aussi.
  touch -t 202601011200 dumps/vieux.sql.gz
  touch dumps/recent.sql.gz
  run ddev db-import -l
  [ "$status" -eq 0 ]
  [[ "$output" == *"recent.sql.gz"* ]]
  [[ "$output" == *"vieux.sql.gz"* ]]
  # la date de chaque dump est affichée (formatage GNU ou BSD selon la plateforme)
  [[ "$output" == *"2026-01-01 12:00"* ]]
  # le plus récent doit apparaître avant le plus ancien
  reste="${output#*recent.sql.gz}"
  [[ "$reste" == *"vieux.sql.gz"* ]]
}

@test "portabilité : ni mapfile (bash 4+) ni find -printf (GNU) dans les commandes" {
  # macOS fournit bash 3.2 et un find BSD : ces deux constructions y échouent.
  # (Les occurrences en commentaire sont ignorées.)
  run grep -rnE '^[^#]*(mapfile|readarray|[[:space:]]-printf[[:space:]])' \
    "$ADDON_DIR/commands"
  [ "$status" -ne 0 ]
}

@test "db-preprod-dump : un ~ en tête de PREPROD_DB_PATH est développé côté serveur" {
  # Appel direct du script (pas via ddev) avec un ssh factice qui se contente
  # d'afficher la commande distante : ni serveur ni base ne sont nécessaires.
  mkdir -p "$TESTDIR/bin"
  cat > "$TESTDIR/bin/ssh" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do last="$a"; done
echo "$last"
STUB
  chmod +x "$TESTDIR/bin/ssh"
  cat > "$PROJDIR/.env" <<'ENVFILE'
PREPROD_USER=user
PREPROD_HOST=example.test
PREPROD_PATH=~/www
PREPROD_DRUSH=drush
PREPROD_DB_PATH=~/public_html/files/dumps
PREPROD_URL=example.test
ENVFILE
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-preprod-dump"
  [ "$status" -eq 0 ]
  # le tilde est remplacé par $HOME, évalué par le shell distant
  [[ "$output" == *'"$HOME/public_html/files/dumps/'* ]]
  [[ "$output" != *'"~/'* ]]
}

@test "db-prod-get : un PROD_DB_PATH relatif est résolu depuis PROD_PATH" {
  # Même principe que le test db-preprod-dump ci-dessus : des stubs ssh/scp
  # rendent le test autonome (ni serveur ni base).
  stub_ssh_scp
  cat > "$PROJDIR/.env" <<'ENVFILE'
PROD_USER=user
PROD_HOST=example.test
PROD_PATH=/home/user/http/site
PROD_DB_PATH=db
ENVFILE
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-prod-get"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/home/user/http/site/db/dump.sql.gz"* ]]
  # et surtout : jamais le chemin nu, qui viserait le home du serveur
  [[ "$output" != *"example.test:db/"* ]]
}

@test "db-prod-get : un PROD_DB_PATH absolu est laissé tel quel" {
  stub_ssh_scp
  cat > "$PROJDIR/.env" <<'ENVFILE'
PROD_USER=user
PROD_HOST=example.test
PROD_PATH=/home/user/http/site
PROD_DB_PATH=/var/backups/sql
ENVFILE
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-prod-get"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/var/backups/sql/dump.sql.gz"* ]]
  [[ "$output" != *"/home/user/http/site/var/backups"* ]]
}

@test "db-preprod-get : un PREPROD_DB_PATH en ~ est laissé au shell distant" {
  stub_ssh_scp
  cat > "$PROJDIR/.env" <<'ENVFILE'
PREPROD_USER=user
PREPROD_HOST=example.test
PREPROD_PATH=/home/user/http/site
PREPROD_DB_PATH=~/dumps
ENVFILE
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-preprod-get"
  [ "$status" -eq 0 ]
  [[ "$output" == *"~/dumps/dump.sql.gz"* ]]
  [[ "$output" != *"/home/user/http/site/~"* ]]
}

@test "db-prod-get échoue explicitement quand PROD_PATH manque" {
  install_addon
  cat > "$PROJDIR/.env" <<'ENVFILE'
PROD_USER=user
PROD_HOST=example.test
PROD_DB_PATH=db
ENVFILE
  run ddev db-prod-get
  [ "$status" -ne 0 ]
  [[ "$output" == *"PROD_PATH"* ]]
  [[ "$output" == *"manquant"* ]]
}

@test "add-on remove supprime toutes les commandes" {
  install_addon
  run ddev add-on remove drupal-tools
  [ "$status" -eq 0 ]
  for c in "${COMMANDS[@]}"; do
    [ ! -e "$HOME/.ddev/commands/host/$c" ]
  done
  [ ! -e "$HOME/.ddev/commands/host/autocomplete/db-import" ]
}
