# use_op_secret: load 1Password secrets into the environment
#
#   use_op_secret op://app/db/password           exports DB_PASSWORD, named after the item and field
#   use_op_secret DB_PASS=op://app/db/password   the same secret with an explicit variable name
#
# References use the 1Password secret reference syntax, query parameters included, for example
# ?attribute=otp. Authentication is whatever the op CLI uses: the desktop app integration, or a
# service account through OP_SERVICE_ACCOUNT_TOKEN.

# $1: secret reference, op://vault/item[/section]/field[?query]
# stdout: variable name built from the item and the field
_op_secret_name() {
  local path=${1#op://} item field
  path=${path%%\?*}
  item=${path#*/}
  item=${item%%/*}
  field=${path##*/}
  printf '%s_%s' "$item" "$field" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9_' '_'
}

use_op_secret() {
  if [[ $# -eq 0 ]]; then
    log_error "use_op_secret: usage: use_op_secret [NAME=]op://vault/item/field ..."
    return 1
  fi
  has op || { log_error "use_op_secret: op not found"; return 1; }

  local arg name ref value count=0
  for arg in "$@"; do
    name="" ref=$arg
    # a reference can contain = in its query, so only split a name off when it is not a reference
    if [[ $arg != op://* && $arg == *=* ]]; then
      name=${arg%%=*}
      ref=${arg#*=}
    fi
    if [[ $ref != op://*/*/* ]]; then
      log_error "use_op_secret: invalid secret reference '$ref', expected op://vault/item/field"
      return 1
    fi
    [[ -n $name ]] || name=$(_op_secret_name "$ref")
    if [[ ! $name =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      log_error "use_op_secret: invalid variable name '$name'"
      return 1
    fi

    value=$(op read "$ref") || {
      log_error "use_op_secret: failed to read $ref"
      return 1
    }
    export "$name=$value"
    ((count++))
  done

  log_status "use_op_secret: loaded $count variable(s)"
}
