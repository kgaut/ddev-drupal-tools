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
  touch -d '2 hours ago' dumps/vieux.sql.gz
  touch dumps/recent.sql.gz
  run ddev db-import -l
  [ "$status" -eq 0 ]
  [[ "$output" == *"recent.sql.gz"* ]]
  [[ "$output" == *"vieux.sql.gz"* ]]
  # le plus récent doit apparaître avant le plus ancien
  reste="${output#*recent.sql.gz}"
  [[ "$reste" == *"vieux.sql.gz"* ]]
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
