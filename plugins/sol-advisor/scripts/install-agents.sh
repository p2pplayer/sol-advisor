#!/bin/sh
# Install Sol Advisor's shipped custom-agent templates without changing Codex config.

set -eu

usage() {
  cat <<'EOF'
Usage: install-agents.sh [--target-dir PATH] [--group legacy|current|all] [--check] [--check-role ROLE ...]

Install the selected group's exact custom-agent templates (default: legacy).
Use --group all to install both groups; current leaves legacy destinations untouched.
Normal mode also migrates only exact byte-matching historical templates where the
role remains the same. It never overwrites a modified, nonregular, or symlinked
destination.

Without --target-dir, the target is "$CODEX_HOME/agents" when CODEX_HOME is already
set, otherwise "$HOME/.codex/agents".

Options:
  --target-dir PATH  Explicit destination directory (absolute or relative).
  --group GROUP      legacy (default), current, or all. No model fallback.
  --check            Verify every role in the selected group; do not create,
                     replace, or remove anything.
  --check-role ROLE  Verify only ROLE; legacy: luna/terra/sol; current:
                     routine/complex/reviewer. Exact selected role names also work.
                     Repeatable and implies
                     --check. Unknown or missing roles fail without mutation.
  --help             Show this help text.
EOF
}

fail() {
  printf '%s\n' "ERROR (earlier writes, if any, are not rolled back): $*" >&2
  exit 1
}

report_preflight_error() {
  printf '%s\n' "ERROR: $*" >&2
  preflight_failed=1
}

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

sha256_file() {
  shasum -a 256 "$1" 2>/dev/null | awk 'NF >= 1 && length($1) == 64 { print $1; exit }'
}

classify_current_or_legacy() {
  destination=$1
  template=$2
  legacy_digest=$3
  legacy_digest_alt=${4-}

  if ! path_exists "$destination"; then
    printf '%s\n' missing
  elif [ -L "$destination" ] || [ ! -f "$destination" ]; then
    printf '%s\n' unsafe
  elif cmp -s "$template" "$destination"; then
    printf '%s\n' current
  else
    digest=$(sha256_file "$destination")
    if [ -n "$digest" ] && {
      [ "$digest" = "$legacy_digest" ] || [ "$digest" = "$legacy_digest_alt" ]
    }; then
      printf '%s\n' legacy
    elif [ -z "$digest" ]; then
      printf '%s\n' unreadable
    else
      printf '%s\n' conflict
    fi
  fi
}

same_state() {
  label=$1
  expected=$2
  actual=$3
  [ "$expected" = "$actual" ] || fail "$label changed after preflight; no further destination files were changed."
}

install_missing() {
  template=$1
  destination=$2
  staged=''

  if path_exists "$destination"; then
    fail "destination changed after preflight and will not be overwritten: $destination"
  fi

  staged=$(mktemp "$target_dir/.sol-advisor-agent.XXXXXX") || fail "could not stage template for installation: $destination"
  if ! cp "$template" "$staged"; then
    rm -f "$staged"
    fail "could not stage template for installation: $destination"
  fi

  if ! ln "$staged" "$destination"; then
    rm -f "$staged"
    fail "destination changed after preflight and will not be overwritten: $destination"
  fi

  rm -f "$staged" || fail "could not remove staged template after installation: $staged"
  printf '%s\n' "INSTALLED: $destination"
}

replace_legacy_role() {
  label=$1
  template=$2
  destination=$3
  legacy_digest=$4
  legacy_digest_alt=${5-}
  staged=''

  [ "$(classify_current_or_legacy "$destination" "$template" "$legacy_digest" "$legacy_digest_alt")" = legacy ] ||
    fail "legacy $label destination changed after preflight and will not be replaced: $destination"

  staged=$(mktemp "$target_dir/.sol-advisor-agent.XXXXXX") || fail "could not stage migrated $label template: $destination"
  if ! cp "$template" "$staged"; then
    rm -f "$staged"
    fail "could not stage migrated $label template: $destination"
  fi

  [ "$(classify_current_or_legacy "$destination" "$template" "$legacy_digest" "$legacy_digest_alt")" = legacy ] || {
    rm -f "$staged"
    fail "legacy $label destination changed after preflight and will not be replaced: $destination"
  }

  if ! mv -f "$staged" "$destination"; then
    rm -f "$staged"
    fail "could not replace exact legacy $label template: $destination"
  fi

  printf '%s\n' "MIGRATED: $destination"
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
template_dir=$script_dir/../agents

if [ -n "${CODEX_HOME-}" ]; then
  target_dir=$CODEX_HOME/agents
else
  [ -n "${HOME-}" ] || fail "HOME is unset and CODEX_HOME was not supplied; pass --target-dir explicitly."
  target_dir=$HOME/.codex/agents
fi

check_only=0
check_roles=''
group=legacy

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-dir)
      [ "$#" -ge 2 ] || fail "--target-dir requires a path."
      [ -n "$2" ] || fail "--target-dir requires a non-empty path."
      case "$2" in
        --*) fail "--target-dir path must be explicit; prefix an option-like relative name with ./ or use an absolute path." ;;
      esac
      target_dir=$2
      shift 2
      ;;
    --group)
      [ "$#" -ge 2 ] || fail "--group requires legacy, current, or all."
      case "$2" in legacy|current|all) group=$2 ;; *) fail "unknown group: $2" ;; esac
      shift 2
      ;;
    --check)
      check_only=1
      shift
      ;;
    --check-role)
      [ "$#" -ge 2 ] || fail "--check-role requires a role in the selected group."
      [ -n "$2" ] || fail "empty --check-role"
      check_only=1
      check_roles=$check_roles$2,
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1 (run with --help for usage)."
      ;;
  esac
done

case "$target_dir" in
  /*) ;;
  *) target_dir=$(pwd -P)/$target_dir ;;
esac

case "$target_dir" in
  /|//) fail "refusing to use the filesystem root as an agent target directory." ;;
esac

# Immutable historical byte digests, calculated from the shipped v0.2.0 role files:
# git show bbc3dc1:plugins/sol-advisor/agents/sol-advisor-luna-implementer.toml | shasum -a 256
# git show bbc3dc1:plugins/sol-advisor/agents/sol-advisor-terra-implementer.toml | shasum -a 256
legacy_luna_sha256=fba1b42849d93737e83b094a2ab0b1611f87ac37db7438c8bbdf581f0813f8eb
legacy_terra_sha256=4425a8c1f21ce8c6af93f96adc253bbc33ea301f1389b3fa8ce350be08584eca
# Immutable v0.5.0 role digests, calculated from the shipped base profiles.
legacy_luna_v050_sha256=5cfaf77f14757074ca5d3cfecd0b8204c91dc14eff8d6119985c64416ddf4853
legacy_terra_v050_sha256=dc329fe87f6f6610c13157ec16432f91c79cf5a541ee3e7448f6afb165dd18ce


# Explicit inventories; old defaults and byte-exact migration remain unchanged.
legacy_specs="luna:sol-advisor-luna-implementer.toml:$legacy_luna_sha256:$legacy_luna_v050_sha256
terra:sol-advisor-terra-implementer.toml:$legacy_terra_sha256:$legacy_terra_v050_sha256
sol:sol-advisor-sol-reviewer.toml::"
current_specs="routine:sol-advisor-current-routine-implementer.toml::
complex:sol-advisor-current-complex-implementer.toml::
reviewer:sol-advisor-current-reviewer.toml::"
case "$group" in
  legacy) specs=$legacy_specs ;;
  current) specs=$current_specs ;;
  all) specs="$legacy_specs
$current_specs" ;;
esac

# Resolve requested roles before inspecting or creating any destination.
selected_specs=''
for spec in $specs; do
  key=${spec%%:*}
  rest=${spec#*:}
  file=${rest%%:*}
  exact=$(printf '%s' "${file%.toml}" | tr '-' '_')
  if [ -z "$check_roles" ]; then
    selected_specs="$selected_specs $spec"
  else
    case ",$check_roles," in
      *,"$key",*|*,"$exact",*) selected_specs="$selected_specs $spec" ;;
    esac
  fi
done
if [ -n "$check_roles" ]; then
  old_ifs=$IFS; IFS=,
  for requested in $check_roles; do
    found=0
    IFS=$old_ifs
    for spec in $selected_specs; do
      key=${spec%%:*}; rest=${spec#*:}; file=${rest%%:*}
      exact=$(printf '%s' "${file%.toml}" | tr '-' '_')
      if [ "$requested" = "$key" ] || [ "$requested" = "$exact" ]; then found=1; fi
    done
    [ "$found" -eq 1 ] || fail "unknown or cross-group role '$requested' for $group"
    IFS=,
  done
  IFS=$old_ifs
fi

unpack_spec() {
  key=${1%%:*}; rest=${1#*:}; file=${rest%%:*}; rest=${rest#*:}
  digest=${rest%%:*}; alt=${rest#*:}
  template=$template_dir/$file; destination=$target_dir/$file
}

preflight_failed=0
# Refuse symlinked ancestors too: a real leaf under a link is not isolated.
ancestor=$target_dir
while [ "$ancestor" != / ] && [ "$ancestor" != . ]; do
  [ ! -L "$ancestor" ] || report_preflight_error "symlinked target ancestor: $ancestor"
  parent=$(dirname "$ancestor")
  [ "$parent" != "$ancestor" ] || break
  ancestor=$parent
done
if path_exists "$target_dir"; then
  [ -d "$target_dir" ] && [ ! -L "$target_dir" ] ||
    report_preflight_error "target directory is not a real directory: $target_dir"
fi
states=''
for spec in $selected_specs; do
  unpack_spec "$spec"
  [ -f "$template" ] && [ ! -L "$template" ] || fail "unsafe shipped template: $template"
  state=$(classify_current_or_legacy "$destination" "$template" "$digest" "$alt")
  states="$states $state"
  if [ "$check_only" -eq 1 ]; then
    [ "$state" = current ] || report_preflight_error "$key template is $state: $destination"
  else
    case "$state" in current|legacy|missing) ;; *) report_preflight_error "$key destination is $state and will not be replaced: $destination" ;; esac
  fi
done
[ "$preflight_failed" -eq 0 ] || exit 1
if [ "$check_only" -eq 1 ]; then
  printf '%s\n' "CHECK PASSED: $group selected roles exactly match $template_dir."
  exit 0
fi
if [ ! -d "$target_dir" ]; then
  mkdir -p "$target_dir" || fail "could not create target directory"
fi
[ -d "$target_dir" ] && [ ! -L "$target_dir" ] || fail "target changed after preflight"

# Recheck the complete set before writing; this is not a cross-file transaction.
set -- $states
for spec in $selected_specs; do
  unpack_spec "$spec"
  same_state "$key" "$1" "$(classify_current_or_legacy "$destination" "$template" "$digest" "$alt")"
  shift
done
for spec in $selected_specs; do
  unpack_spec "$spec"
  state=$(classify_current_or_legacy "$destination" "$template" "$digest" "$alt")
  case "$state" in
    missing) install_missing "$template" "$destination" ;;
    legacy) replace_legacy_role "$key" "$template" "$destination" "$digest" "$alt" ;;
    current) printf '%s\n' "ALREADY CURRENT: $destination" ;;
    *) fail "destination changed; earlier writes may exist: $destination" ;;
  esac
done
for spec in $selected_specs; do
  unpack_spec "$spec"
  [ "$(classify_current_or_legacy "$destination" "$template" "$digest" "$alt")" = current ] ||
    fail "post-install exactness failed; earlier writes may exist: $destination"
done
printf '%s\n' "INSTALL PASSED: $group roles exactly match $template_dir."
