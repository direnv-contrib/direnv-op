#!/usr/bin/env bats

# Tests for lib/op_item.sh (use_op_item)
#
# Requires bats-core: https://github.com/bats-core/bats-core, direnv and jq
# Run: bats tests/

export TEST_HELPER
TEST_HELPER="$BATS_TEST_DIRNAME/helper.bash"

# An item in the shape of `op item get --format json`
export ITEM_JSON='{
  "id": "abc123", "title": "db",
  "fields": [
    {"id": "username", "type": "STRING", "label": "username", "value": "alice"},
    {"id": "password", "type": "CONCEALED", "label": "password", "value": "hunter2"},
    {"id": "notesPlain", "type": "STRING", "purpose": "NOTES", "label": "notesPlain"},
    {"id": "port", "type": "STRING", "label": "port number", "value": "5432"},
    {"id": "empty", "type": "STRING", "label": "empty", "value": ""}
  ]
}'

# ---------------------------------------------------------------------------
# Loading items
# ---------------------------------------------------------------------------

@test "every field with a value becomes a variable named after its label" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "$ITEM_JSON"; }
    use_op_item app/db
    echo "USERNAME=$USERNAME PASSWORD=$PASSWORD PORT_NUMBER=$PORT_NUMBER"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "USERNAME=alice PASSWORD=hunter2 PORT_NUMBER=5432" ]]
}

@test "fields without a value are skipped" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset NOTESPLAIN EMPTY
    op() { echo "$ITEM_JSON"; }
    use_op_item app/db
    echo "NOTESPLAIN=${NOTESPLAIN-unset} EMPTY=${EMPTY-unset}"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "NOTESPLAIN=unset EMPTY=unset" ]]
}

@test "PREFIX=vault/item adds the prefix to every variable" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "$ITEM_JSON"; }
    use_op_item DB=app/db
    echo "DB_USERNAME=$DB_USERNAME DB_PASSWORD=$DB_PASSWORD"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "DB_USERNAME=alice DB_PASSWORD=hunter2" ]]
}

@test "vault/item reads the item from that vault" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "args: $*" >&2; echo "$ITEM_JSON"; }
    use_op_item app/db
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"args: item get db --format json --reveal --vault app"* ]]
}

@test "an item without a vault is searched in every vault" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "args: $*" >&2; echo "$ITEM_JSON"; }
    use_op_item db
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"args: item get db --format json --reveal"* ]]
  [[ "$output" != *"--vault"* ]]
}

@test "an item name with spaces is passed as one argument" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "argc=$# item=$3" >&2; echo "$ITEM_JSON"; }
    use_op_item "app/prod database"
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"item=prod database"* ]]
}

@test "several items can be loaded in one call" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() {
      case "$3" in
        a) echo "{\"fields\":[{\"label\":\"token\",\"value\":\"one\"}]}" ;;
        b) echo "{\"fields\":[{\"label\":\"token\",\"value\":\"two\"}]}" ;;
      esac
    }
    use_op_item A=a B=b
    echo "A_TOKEN=$A_TOKEN B_TOKEN=$B_TOKEN"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "A_TOKEN=one B_TOKEN=two" ]]
}

@test "an item without fields loads nothing" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "{\"id\":\"x\"}"; }
    use_op_item app/empty
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"use_op_item: loaded 0 variable(s)"* ]]
}

@test "the status line reports how many variables were loaded" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "$ITEM_JSON"; }
    use_op_item app/db
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"use_op_item: loaded 3 variable(s)"* ]]
}

# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

@test "no arguments prints the usage and fails" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    use_op_item
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"usage: use_op_item [PREFIX=][vault/]item"* ]]
}

@test "fails when op is not installed" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    has() { [[ "$1" != "op" ]] && type "$1" &>/dev/null; }
    use_op_item app/db
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"op not found"* ]]
}

@test "fails when jq is not installed" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { :; }
    has() { [[ "$1" != "jq" ]] && type "$1" &>/dev/null; }
    use_op_item app/db
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"jq not found"* ]]
}

@test "fails on an empty item" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "$ITEM_JSON"; }
    use_op_item app/
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"invalid item 'app/'"* ]]
}

@test "fails when the item cannot be read" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { return 1; }
    use_op_item app/missing
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"failed to read missing"* ]]
}

@test "fails on a label that is not a valid variable name" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "{\"fields\":[{\"label\":\"1st\",\"value\":\"v\"}]}"; }
    use_op_item app/db
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"invalid variable name '1ST'"* ]]
}
