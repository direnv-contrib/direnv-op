# use_op_item: load every field of a 1Password item into the environment
#
#   use_op_item app/db           one variable per field, named after its label, uppercased
#   use_op_item DB=app/db        the same, with DB_ as a prefix
#   use_op_item db               an item name or id without a vault, searched in every vault
#
# Fields without a label or a value are skipped. When two fields share a label, the later one wins.

# $1: variable name prefix (optional)
# stdin: op item get JSON
# stdout: NUL-delimited name/value pairs
_op_item_emit() {
  jq -j --arg prefix "$1" '
    def envname: ascii_upcase | gsub("[^A-Z0-9_]"; "_");
    (if $prefix != "" then $prefix + "_" else "" end) as $p
    | (.fields // [])[]
    | select((.label // "") != "" and (.value | type) == "string" and .value != "")
    | ($p + (.label | envname)), "\u0000", .value, "\u0000"'
}

use_op_item() {
  if [[ $# -eq 0 ]]; then
    log_error "use_op_item: usage: use_op_item [PREFIX=][vault/]item ..."
    return 1
  fi
  has op || { log_error "use_op_item: op not found"; return 1; }
  has jq || { log_error "use_op_item: jq not found"; return 1; }

  local arg prefix item vault json key value count=0
  local -a cmd
  for arg in "$@"; do
    prefix="" item=$arg vault=""
    if [[ $arg == *=* ]]; then
      prefix=${arg%%=*}
      item=${arg#*=}
    fi
    if [[ $item == */* ]]; then
      vault=${item%%/*}
      item=${item#*/}
    fi
    if [[ -z $item ]]; then
      log_error "use_op_item: invalid item '$arg'"
      return 1
    fi

    cmd=(op item get "$item" --format json --reveal)
    [[ -n $vault ]] && cmd+=(--vault "$vault")
    json=$("${cmd[@]}") || {
      log_error "use_op_item: failed to read $item"
      return 1
    }

    while IFS= read -r -d '' key && IFS= read -r -d '' value; do
      if [[ ! $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        log_error "use_op_item: invalid variable name '$key'"
        return 1
      fi
      export "$key=$value"
      ((count++))
    done < <(printf '%s' "$json" | _op_item_emit "$prefix")
  done

  log_status "use_op_item: loaded $count variable(s)"
}
