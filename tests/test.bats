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

# Stubs ssh/scp « serveur local » : la machine de test joue le serveur. Le ssh
# exécute la commande distante (son dernier argument) avec le sh local, depuis
# $HOME comme une vraie session ; le scp copie « hôte:chemin » vers la
# destination. C'est donc le script distant lui-même qui est testé.
stub_ssh_scp_local() {
  mkdir -p "$TESTDIR/bin"
  cat > "$TESTDIR/bin/ssh" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do last="$a"; done
cd "$HOME" && exec sh -c "$last"
STUB
  cat > "$TESTDIR/bin/scp" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do src="${dst:-}"; dst="$a"; done
cd "$HOME" && exec sh -c "cp ${src#*:} \"\$1\"" sh "$dst"
STUB
  chmod +x "$TESTDIR/bin/ssh" "$TESTDIR/bin/scp"
}

# Stub ddev, pour appeler les scripts directement : chaque appel est noté dans
# $TESTDIR/ddev.log, et « export-db --file=… » crée le fichier attendu.
stub_ddev() {
  mkdir -p "$TESTDIR/bin"
  cat > "$TESTDIR/bin/ddev" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$TESTDIR/ddev.log"
if [ "$1" = export-db ]; then
  for a in "$@"; do case "$a" in --file=*) : > "${a#--file=}" ;; esac; done
fi
exit 0
STUB
  chmod +x "$TESTDIR/bin/ddev"
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  mkdir -p "$PROJDIR/files/dumps"
  touch "$PROJDIR/files/dumps/dump.sql.gz"
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

@test "-h affiche l'aide sans exécuter la commande" {
  # Sans annotation « ## Flags: », DDEV transmet -h au script, qui s'exécute :
  # téléchargement depuis la prod pour db-*-get, écrasement de la base locale
  # pour db-*-import. Aucune variable n'est définie ici : une exécution se
  # trahirait par une erreur « manquant » au lieu de l'aide.
  install_addon
  for c in "${COMMANDS[@]}"; do
    run ddev "$c" -h
    [ "$status" -eq 0 ] || { echo "$c -h : code $status"; echo "$output"; return 1; }
    [[ "$output" == *"help for $c"* ]]
    [[ "$output" != *"manquant"* ]]
  done
}

@test "toutes les commandes déclarent « ## Flags: » (sinon -h exécute la commande)" {
  for f in "$ADDON_DIR"/commands/host/*; do
    [ -f "$f" ] || continue
    grep -q '^## Flags: ' "$f" || { echo "« ## Flags: » absent : $f"; return 1; }
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
  # le stub ne renvoie pas d'âge : la date est signalée comme inconnue
  [[ "$output" == *"Date du dump : inconnue"* ]]
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

@test "db-prod-dump : le listage final trouve un PROD_DB_PATH relatif à PROD_PATH" {
  # Avant #10, le ls final se lançait depuis le home SSH : code 2 après un
  # dump pourtant réussi.
  stub_ssh_scp_local
  cat > "$TESTDIR/bin/drush" <<'STUB'
#!/usr/bin/env bash
echo "faux dump"
STUB
  chmod +x "$TESTDIR/bin/drush"
  mkdir -p "$TESTDIR/remote/site/db"
  cat > "$PROJDIR/.env" <<ENVFILE
PROD_USER=user
PROD_HOST=example.test
PROD_PATH=$TESTDIR/remote/site
PROD_DRUSH=$TESTDIR/bin/drush
PROD_DB_PATH=db
PROD_URL=example.test
ENVFILE
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-prod-dump"
  [ "$status" -eq 0 ]
  # le dump est écrit sous PROD_PATH, et le ls final le liste
  ls "$TESTDIR"/remote/site/db/*-example.test-prod.sql.gz
  [[ "$output" == *"-example.test-prod.sql.gz"* ]]
}

@test "db-prod-get : affiche la date du dump et avertit s'il a plus de 24 h" {
  stub_ssh_scp_local
  mkdir -p "$TESTDIR/remote/site/db"
  touch -t 202601011200 "$TESTDIR/remote/site/db/vieux.sql.gz"
  cat > "$PROJDIR/.env" <<ENVFILE
PROD_USER=user
PROD_HOST=example.test
PROD_PATH=$TESTDIR/remote/site
PROD_DB_PATH=db
ENVFILE
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-prod-get"
  [ "$status" -eq 0 ]
  [ -f "$PROJDIR/files/dumps/vieux.sql.gz" ]
  [[ "$output" == *"Date du dump : 2026-01-01 12:00"* ]]
  [[ "$output" == *"Attention : ce dump a plus de 24 h"* ]]
}

@test "db-preprod-get : un dump récent est daté sans avertissement (dossier en ~)" {
  stub_ssh_scp_local
  mkdir -p "$HOME/dumps"
  touch -t 202601011200 "$HOME/dumps/vieux.sql.gz"
  touch "$HOME/dumps/recent.sql.gz"
  # heredoc non protégé pour $TESTDIR ; le ~ n'y est pas développé
  cat > "$PROJDIR/.env" <<ENVFILE
PREPROD_USER=user
PREPROD_HOST=example.test
PREPROD_PATH=$TESTDIR/remote/site
PREPROD_DB_PATH=~/dumps
ENVFILE
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-preprod-get"
  [ "$status" -eq 0 ]
  [ -f "$PROJDIR/files/dumps/recent.sql.gz" ]
  [[ "$output" == *"(il y a 0 min)"* ]]
  [[ "$output" != *"Attention"* ]]
}

@test "db-prod-get : un dossier distant absent donne une erreur explicite" {
  stub_ssh_scp_local
  cat > "$PROJDIR/.env" <<ENVFILE
PROD_USER=user
PROD_HOST=example.test
PROD_PATH=$TESTDIR/remote/site
PROD_DB_PATH=absent
ENVFILE
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-prod-get"
  [ "$status" -eq 1 ]
  [[ "$output" == *"aucun dump .sql.gz"* ]]
}

@test "db-import : un projet Drupal garde drush deploy, cr et uli" {
  stub_ddev
  DDEV_PROJECT_TYPE=drupal11 run bash "$ADDON_DIR/commands/host/db-import" -y
  [ "$status" -eq 0 ]
  [ "$(cat "$TESTDIR/ddev.log")" = "import-db --file=$PROJDIR/files/dumps/dump.sql.gz
drush deploy
drush cr
drush uli" ]
}

@test "db-import : un projet symfony n'a que console cache:clear, sans drush" {
  stub_ddev
  DDEV_PROJECT_TYPE=symfony run bash "$ADDON_DIR/commands/host/db-import" -y
  [ "$status" -eq 0 ]
  [ "$(cat "$TESTDIR/ddev.log")" = "import-db --file=$PROJDIR/files/dumps/dump.sql.gz
console cache:clear" ]
}

@test "db-import : un autre type n'a aucune étape, avec renvoi au hook post-import-db" {
  stub_ddev
  DDEV_PROJECT_TYPE=php run bash "$ADDON_DIR/commands/host/db-import" -y
  [ "$status" -eq 0 ]
  [ "$(cat "$TESTDIR/ddev.log")" = "import-db --file=$PROJDIR/files/dumps/dump.sql.gz" ]
  [[ "$output" == *"post-import-db"* ]]
}

@test "db-import -n : le dry-run liste les étapes du type, sans rien lancer" {
  stub_ddev
  DDEV_PROJECT_TYPE=symfony run bash "$ADDON_DIR/commands/host/db-import" -n
  [ "$status" -eq 0 ]
  [[ "$output" == *"type symfony"* ]]
  [[ "$output" == *"ddev console cache:clear"* ]]
  [[ "$output" != *"drush"* ]]
  [ ! -e "$TESTDIR/ddev.log" ]
}

@test "db-export : drush cr pour Drupal seulement" {
  stub_ddev
  DDEV_PROJECT_TYPE=drupal10 run bash "$ADDON_DIR/commands/host/db-export"
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$TESTDIR/ddev.log")" = "drush cr" ]
  rm "$TESTDIR/ddev.log"
  DDEV_PROJECT_TYPE=symfony run bash "$ADDON_DIR/commands/host/db-export"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$TESTDIR/ddev.log")" -eq 1 ]
  grep -q '^export-db ' "$TESTDIR/ddev.log"
}

@test "le type DDEV du projet arrive jusqu'à db-import (projet symfony)" {
  install_addon
  ddev config --project-type=symfony >/dev/null 2>&1
  mkdir -p files/dumps
  touch files/dumps/dump.sql.gz
  run ddev db-import -n
  [ "$status" -eq 0 ]
  [[ "$output" == *"type symfony"* ]]
  [[ "$output" == *"ddev console cache:clear"* ]]
  [[ "$output" != *"drush"* ]]
}

@test ".env.local passe avant .env pour DB_DUMP_DIR" {
  echo "DB_DUMP_DIR=dumps-env" > "$PROJDIR/.env"
  echo "DB_DUMP_DIR=dumps-local" > "$PROJDIR/.env.local"
  mkdir -p "$PROJDIR/dumps-env" "$PROJDIR/dumps-local"
  touch "$PROJDIR/dumps-env/depuis-env.sql.gz" "$PROJDIR/dumps-local/depuis-local.sql.gz"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-import" -l
  [ "$status" -eq 0 ]
  [[ "$output" == *"depuis-local.sql.gz"* ]]
  [[ "$output" == *"(.env.local)"* ]]
  [[ "$output" != *"depuis-env.sql.gz"* ]]
}

@test ".env.local passe avant .env pour les variables PROD_*" {
  stub_ssh_scp
  cat > "$PROJDIR/.env" <<'ENVFILE'
PROD_USER=user
PROD_HOST=depuis-env.test
PROD_PATH=/home/user/http/site
PROD_DB_PATH=db
ENVFILE
  echo "PROD_HOST=depuis-local.test" > "$PROJDIR/.env.local"
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-prod-get"
  [ "$status" -eq 0 ]
  [[ "$output" == *"user@depuis-local.test:"* ]]
  [[ "$output" != *"depuis-env.test"* ]]
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
