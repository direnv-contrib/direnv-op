# direnv-op

> 1Password for direnv — load secrets and whole items into your environment from a `.envrc`.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![CI](https://github.com/direnv-contrib/direnv-op/actions/workflows/ci.yml/badge.svg)](https://github.com/direnv-contrib/direnv-op/actions/workflows/ci.yml)

Stop copying secrets into `.env` files. `direnv-op` adds two functions to your `.envrc`: `use_op_secret` reads secrets by 1Password secret reference, and `use_op_item` loads every field of an item. Both run `op` when you enter a directory and export the values as environment variables.

## Requirements

- [direnv](https://direnv.net) (`direnv`)
- [1Password CLI](https://developer.1password.com/docs/cli/) (`op`), signed in through the desktop app integration or a service account
- [jq](https://jqlang.org) (`jq`) — only for `use_op_item`

**macOS (Homebrew):**

```bash
brew install direnv jq
brew install --cask 1password-cli
```

**Nix:**

```bash
nix profile install nixpkgs#direnv nixpkgs#jq nixpkgs#_1password-cli
```

## Installation

direnv loads every `*.sh` file in `~/.config/direnv/lib/` before it evaluates a `.envrc`, so installing means making the files in `lib/` available there.

### Using Nix

Add the flake as an input, and install its package:

```nix
inputs.direnv-op.url = "github:direnv-contrib/direnv-op";
```

```nix
environment.systemPackages = [ inputs.direnv-op.packages.${system}.default ];
```

The package places the scripts in `share/direnv-op`. With Home Manager managing direnv, source them from the standard library:

```nix
programs.direnv.stdlib = ''
  for lib in ${inputs.direnv-op.packages.${system}.default}/share/direnv-op/*.sh; do
    source "$lib"
  done
'';
```

If you manage `~/.config/direnv` yourself, put the same loop in `~/.config/direnv/lib/direnv-op.sh`, pointing at the package path.

### Manual

```bash
git clone https://github.com/direnv-contrib/direnv-op.git ~/.local/share/direnv-op
mkdir -p ~/.config/direnv/lib
ln -s ~/.local/share/direnv-op/lib/*.sh ~/.config/direnv/lib/
```

## Usage

Call the functions from a `.envrc`:

```bash
use_op_secret op://app/db/password            # exports PASSWORD
use_op_secret DB_PASS=op://app/db/password    # the same secret, with an explicit name

use_op_item app/db                            # every field of the item, one variable each
use_op_item DB=app/db                         # the same, with a DB_ prefix
```

### use_op_secret

Takes [secret references](https://developer.1password.com/docs/cli/secret-reference-syntax/), `op://vault/item/field` or `op://vault/item/section/field`, including query parameters such as `?attribute=otp`.

| Argument | Result |
|----------|--------|
| `op://app/db/password` | One variable named after the field, `PASSWORD` |
| `op://app/cloud/API_TOKEN` | A field that is already uppercase keeps its name, `API_TOKEN` |
| `NAME=op://app/db/password` | The same value, exported as `NAME` |
| `op://app/db/one-time password?attribute=otp` | The one-time password, named `ONE_TIME_PASSWORD` |

The default name is the last path segment, uppercased, and characters outside `A-Z`, `0-9` and `_` become `_`. This is the same rule as [direnv-aws](https://github.com/direnv-contrib/direnv-aws). The item is not part of the name, so two items with a field of the same name collide, and `NAME=` gives each its own.

A multi-line value, such as a private key, keeps its inner newlines. A trailing newline is not part of the value, so add one back when you write a key to a file. A file attached to an item is read by its file name, `op://app/signing-key/key.pem`, and its default name is `KEY_PEM`.

### use_op_item

Runs `op item get --format json --reveal` and exports every field that has a label and a value.

| Argument | Result |
|----------|--------|
| `app/db` | One variable per field, named after its label, uppercased |
| `DB=app/db` | The same, with `DB_` in front of every name |
| `db` | An item name or id without a vault, searched in every vault |

Fields without a label or a value are skipped. When two fields share a label, the later one wins, so use a prefix when you load several items.

## Credentials

The helpers use whatever the `op` CLI is signed in with:

- **Desktop app integration:** if the 1Password app is locked, `op` asks you to unlock it when you enter the directory.
- **Service account:** set `OP_SERVICE_ACCOUNT_TOKEN` in your environment, for example in CI. Service accounts need the vault in the reference, so `use_op_item` should be called with `vault/item`.

## Behavior

- A failed read, a malformed reference, or a name that is not a valid variable name stops the call and returns status 1 with an error message. Variables exported by earlier arguments in the same call stay set.
- Values are exported into the environment of that directory. Anything that runs there can read them, and direnv's `.envrc` trust model applies, so review a `.envrc` before you run `direnv allow`.
- A `.envrc` that uses these functions contains references and item names only, never the values, so it is safe to commit.

## Development

```bash
nix develop
bats tests/
```

The tests stub `op` with a shell function and load direnv's own standard library, so they run without a 1Password account. The item tests use a sample in the shape that `op item get --format json` returns.

## The direnv-contrib Ecosystem

| Repo | What it provides |
|------|-----------------|
| [direnv-aws](https://github.com/direnv-contrib/direnv-aws) | AWS Secrets Manager and SSM Parameter Store for direnv |
| [direnv-gcp](https://github.com/direnv-contrib/direnv-gcp) | Google Secret Manager and project selection for direnv |
| **direnv-op** ← you are here | 1Password secrets and items for direnv |

## License

[MIT](LICENSE) — Copyright (c) 2026 direnv-contrib

<!-- markdownlint-disable-file MD013 -->
