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

# Stub mysqldump, pour le mode <ENV>_DB_NAME (avec stub_ssh_scp_local) : note
# ses arguments et produit un dump selon STUB_MYSQLDUMP — ok, echec (erreur
# après un début de dump) ou tronque (sortie sans la ligne de fin).
stub_mysqldump() {
  mkdir -p "$TESTDIR/bin"
  cat > "$TESTDIR/bin/mysqldump" <<'STUB'
#!/usr/bin/env bash
echo "$*" > "$TESTDIR/mysqldump.args"
echo "-- MariaDB dump"
echo "CREATE TABLE t (id int);"
case "${STUB_MYSQLDUMP:-ok}" in
  echec)   echo "mysqldump: Got error: 1045: Access denied" >&2; exit 2 ;;
  tronque) exit 0 ;;
esac
echo "-- Dump completed on 2026-09-17 15:24:24"
STUB
  chmod +x "$TESTDIR/bin/mysqldump"
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

@test "chaque fichier installé porte #ddev-generated puis #ddev-silent-no-warn" {
  # #ddev-generated : DDEV met à jour et supprime le fichier. #ddev-silent-no-warn :
  # DDEV ne le signale pas comme configuration personnalisée dans les projets qui
  # n'ont pas le manifeste de l'addon (tous, sauf celui de l'installation).
  files="$(sed -n '/^global_files:/,/^[^ ]/s/^  - //p' "$ADDON_DIR/install.yaml")"
  [ "$(printf '%s\n' "$files" | wc -l)" -eq 11 ]
  for f in $files; do
    [ "$(sed -n 2p "$ADDON_DIR/$f")" = "#ddev-generated" ] || { echo "l.2 : $f"; return 1; }
    [ "$(sed -n 3p "$ADDON_DIR/$f")" = "#ddev-silent-no-warn" ] || { echo "l.3 : $f"; return 1; }
  done
}

@test "un projet sans le manifeste de l'addon ne signale pas ses commandes globales" {
  install_addon
  mkdir -p "$TESTDIR/autre"
  cd "$TESTDIR/autre"
  ddev config --project-name=test-drupal-tools-autre --project-type=php --auto >/dev/null 2>&1
  [ ! -e .ddev/addon-metadata/drupal-tools ]
  run ddev debug check-custom-config
  [[ "$output" != *"commands/host/"* ]]
  [[ "$output" != *"unexpected #ddev-generated"* ]]
  # toujours visibles, annotées, avec --all
  run ddev debug check-custom-config --all
  [[ "$output" == *"commands/host/db-import (unexpected #ddev-generated) (#ddev-silent-no-warn)"* ]]
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

@test "db-preprod-dump : sans PREPROD_DRUSH, un projet non Drupal a un message explicite" {
  cat > "$PROJDIR/.env" <<'ENVFILE'
PREPROD_USER=user
PREPROD_HOST=example.test
PREPROD_PATH=/home/user/http/site
PREPROD_DB_PATH=db
PREPROD_URL=example.test
ENVFILE
  export DDEV_APPROOT="$PROJDIR"
  DDEV_PROJECT_TYPE=symfony run bash "$ADDON_DIR/commands/host/db-preprod-dump"
  [ "$status" -eq 1 ]
  [[ "$output" == *"réservé aux projets Drupal"* ]]
  [[ "$output" == *"symfony"* ]]
  # un projet Drupal garde le message générique
  DDEV_PROJECT_TYPE=drupal11 run bash "$ADDON_DIR/commands/host/db-preprod-dump"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PREPROD_DRUSH manquant"* ]]
  [[ "$output" != *"réservé"* ]]
}

@test "db-prod-get : pas de double slash quand PROD_PATH ou PROD_DB_PATH finit par /" {
  stub_ssh_scp
  cat > "$PROJDIR/.env" <<'ENVFILE'
PROD_USER=user
PROD_HOST=example.test
PROD_PATH=/home/user/http/site/
PROD_DB_PATH=files/dumps/
ENVFILE
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-prod-get"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/home/user/http/site/files/dumps/dump.sql.gz"* ]]
  [[ "$output" != *"//"* ]]
}

@test "db-prod-get : avec PROD_DB_NAME seul, dump mysqldump frais posé en local" {
  stub_ssh_scp_local
  stub_mysqldump
  cat > "$PROJDIR/.env" <<'ENVFILE'
PROD_USER=user
PROD_HOST=example.test
PROD_DB_NAME=appdb
PROD_URL=example.test
ENVFILE
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-prod-get"
  [ "$status" -eq 0 ]
  dumps=("$PROJDIR"/files/dumps/*-example.test-prod.sql.gz)
  [ "${#dumps[@]}" -eq 1 ]
  [ -f "${dumps[0]}" ]
  gzip -t "${dumps[0]}"
  [[ "$(gzip -dc "${dumps[0]}" | tail -n 1)" == "-- Dump completed"* ]]
  [ "$(ls "$PROJDIR/files/dumps" | wc -l)" -eq 1 ]   # pas de .part résiduel
  # options indispensables, et pas de --events
  args="$(cat "$TESTDIR/mysqldump.args")"
  [[ "$args" == *"--single-transaction"* ]]
  [[ "$args" == *"--routines"* ]]
  [[ "$args" == *"--no-tablespaces"* ]]
  [[ "$args" == *" appdb" ]]
  [[ "$args" != *"--events"* ]]
  [[ "$output" == *"Dump téléchargé"* ]]
}

@test "db-prod-get : un mysqldump en échec ne laisse aucun fichier" {
  stub_ssh_scp_local
  stub_mysqldump
  printf 'PROD_USER=user\nPROD_HOST=example.test\nPROD_DB_NAME=appdb\n' > "$PROJDIR/.env"
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  STUB_MYSQLDUMP=echec run bash "$ADDON_DIR/commands/host/db-prod-get"
  [ "$status" -eq 1 ]
  # pipefail côté serveur signale l'échec ; sans lui (dash ancien), c'est
  # l'absence de la ligne de fin
  [[ "$output" == *"le dump a échoué"* || "$output" == *"dump incomplet"* ]]
  [ -d "$PROJDIR/files/dumps" ]
  [ -z "$(ls -A "$PROJDIR/files/dumps")" ]
}

@test "db-preprod-get : un dump sans sa ligne de fin est refusé et supprimé" {
  stub_ssh_scp_local
  stub_mysqldump
  printf 'PREPROD_USER=user\nPREPROD_HOST=example.test\nPREPROD_DB_NAME=appdb_pp\n' > "$PROJDIR/.env"
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  STUB_MYSQLDUMP=tronque run bash "$ADDON_DIR/commands/host/db-preprod-get"
  [ "$status" -eq 1 ]
  [[ "$output" == *"dump incomplet"* ]]
  [ -z "$(ls -A "$PROJDIR/files/dumps")" ]
}

@test "db-prod-get : PROD_DB_PATH l'emporte sur PROD_DB_NAME" {
  stub_ssh_scp
  cat > "$PROJDIR/.env" <<'ENVFILE'
PROD_USER=user
PROD_HOST=example.test
PROD_PATH=/home/user/http/site
PROD_DB_PATH=db
PROD_DB_NAME=appdb
ENVFILE
  export PATH="$TESTDIR/bin:$PATH"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-prod-get"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/home/user/http/site/db/dump.sql.gz"* ]]
  [[ "$output" != *"mysqldump"* ]]
}

@test "db-prod-get : sans PROD_DB_PATH ni PROD_DB_NAME, erreur explicite" {
  printf 'PROD_USER=user\nPROD_HOST=example.test\nPROD_PATH=/srv/site\n' > "$PROJDIR/.env"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-prod-get"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PROD_DB_PATH ou PROD_DB_NAME manquant"* ]]
}

@test "db-prod-dump : sans drush mais avec PROD_DB_NAME, renvoi vers db-prod-get" {
  printf 'PROD_USER=user\nPROD_HOST=example.test\nPROD_PATH=/srv/site\nPROD_DB_NAME=appdb\n' > "$PROJDIR/.env"
  export DDEV_APPROOT="$PROJDIR"
  DDEV_PROJECT_TYPE=symfony run bash "$ADDON_DIR/commands/host/db-prod-dump"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ddev db-prod-get"* ]]
}

@test "db-import ignore un dump en cours de téléchargement (.part)" {
  mkdir -p "$PROJDIR/files/dumps"
  touch -t 202601011200 "$PROJDIR/files/dumps/complet.sql.gz"
  touch "$PROJDIR/files/dumps/en-cours.sql.gz.part"
  export DDEV_APPROOT="$PROJDIR"
  run bash "$ADDON_DIR/commands/host/db-import" -l
  [ "$status" -eq 0 ]
  [[ "$output" == *"complet.sql.gz"* ]]
  [[ "$output" != *"en-cours"* ]]
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
