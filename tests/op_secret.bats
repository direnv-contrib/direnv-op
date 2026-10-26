#!/usr/bin/env bats

# Tests for lib/op_secret.sh (use_op_secret)
#
# Requires bats-core: https://github.com/bats-core/bats-core and direnv
# Run: bats tests/

export TEST_HELPER
TEST_HELPER="$BATS_TEST_DIRNAME/helper.bash"

# ---------------------------------------------------------------------------
# Loading secrets
# ---------------------------------------------------------------------------

@test "a reference exports a variable named after the field" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "hunter2"; }
    use_op_secret op://app/db/password
    echo "PASSWORD=$PASSWORD"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "PASSWORD=hunter2" ]]
}

@test "NAME=reference exports the secret under that name" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "hunter2"; }
    use_op_secret DB_PASS=op://app/db/password
    echo "DB_PASS=$DB_PASS"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "DB_PASS=hunter2" ]]
}

@test "spaces and punctuation in the field become underscores" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "value"; }
    use_op_secret "op://app/my db/api key"
    echo "API_KEY=$API_KEY"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "API_KEY=value" ]]
}

@test "an uppercase field is exported as it is" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "token-value"; }
    use_op_secret op://app/cloud/CLOUD_API_TOKEN
    echo "CLOUD_API_TOKEN=$CLOUD_API_TOKEN"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "CLOUD_API_TOKEN=token-value" ]]
}

@test "an uppercase field behind a section is exported as it is" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "token-value"; }
    use_op_secret op://app/cloud/secrets/CLOUD_API_TOKEN
    echo "CLOUD_API_TOKEN=$CLOUD_API_TOKEN"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "CLOUD_API_TOKEN=token-value" ]]
}

@test "a lowercase field is uppercased" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "value"; }
    use_op_secret op://app/db/api_key
    echo "API_KEY=$API_KEY"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "API_KEY=value" ]]
}

@test "a mixed-case field is uppercased without a separator" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "value"; }
    use_op_secret op://app/db/ApiKey
    echo "APIKEY=$APIKEY"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "APIKEY=value" ]]
}

@test "an uppercase field with a query parameter is exported as it is" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "123456"; }
    use_op_secret "op://app/db/OTP?attribute=otp"
    echo "OTP=$OTP"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "OTP=123456" ]]
}

@test "the item name is not part of the derived name" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "value"; }
    use_op_secret op://app/first/token
    echo "TOKEN=$TOKEN FIRST_TOKEN=${FIRST_TOKEN-unset}"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "TOKEN=value FIRST_TOKEN=unset" ]]
}

@test "a section in the reference is skipped when naming the variable" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "value"; }
    use_op_secret op://app/db/credentials/password
    echo "PASSWORD=$PASSWORD"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "PASSWORD=value" ]]
}

@test "a query parameter is passed to op but not used in the name" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "args: $*" >&2; echo "123456"; }
    use_op_secret "op://app/db/one-time password?attribute=otp"
    echo "ONE_TIME_PASSWORD=$ONE_TIME_PASSWORD"
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"args: read op://app/db/one-time password?attribute=otp"* ]]
  [[ "${lines[-1]}" == "ONE_TIME_PASSWORD=123456" ]]
}

@test "NAME= is only split off a name, not off a query parameter" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "args: $*" >&2; echo "123456"; }
    use_op_secret OTP="op://app/db/otp?attribute=otp"
    echo "OTP=$OTP"
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"args: read op://app/db/otp?attribute=otp"* ]]
  [[ "${lines[-1]}" == "OTP=123456" ]]
}

@test "several references can be loaded in one call" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { case "$2" in *login*) echo "alice" ;; *secret*) echo "hunter2" ;; esac; }
    use_op_secret op://app/db/login op://app/db/secret
    echo "LOGIN=$LOGIN SECRET=$SECRET"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "LOGIN=alice SECRET=hunter2" ]]
}

@test "a multi-line secret keeps its inner newlines" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { printf "line1\nline2\n"; }
    use_op_secret KEY=op://app/ssh/private
    printf "%s" "$KEY"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-2]}" == "line1" ]]
  [[ "${lines[-1]}" == "line2" ]]
}

@test "the status line reports how many variables were loaded" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "v"; }
    use_op_secret op://a/b/c op://a/b/d
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"use_op_secret: loaded 2 variable(s)"* ]]
}

# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

@test "no arguments prints the usage and fails" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    use_op_secret
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"usage: use_op_secret [NAME=]op://vault/item/field"* ]]
}

@test "fails when op is not installed" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    has() { [[ "$1" != "op" ]] && type "$1" &>/dev/null; }
    use_op_secret op://app/db/password
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"op not found"* ]]
}

@test "fails on something that is not a secret reference" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "v"; }
    use_op_secret not-a-reference
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"invalid secret reference 'not-a-reference'"* ]]
}

@test "fails on a reference without a field" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "v"; }
    use_op_secret op://app/db
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"invalid secret reference 'op://app/db'"* ]]
}

@test "fails when the secret cannot be read" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { return 1; }
    use_op_secret op://app/db/password
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"failed to read op://app/db/password"* ]]
}

@test "fails on a name that is not a valid variable name" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "v"; }
    use_op_secret 1BAD=op://app/db/password
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"invalid variable name '1BAD'"* ]]
}

@test "fails when the derived name does not start with a letter" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    op() { echo "v"; }
    use_op_secret op://app/db/1st
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"invalid variable name '1ST'"* ]]
}
