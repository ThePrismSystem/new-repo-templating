#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
# shellcheck source=lib/compose.sh
source "$SCRIPT_DIR/lib/compose.sh"

# --- Defaults ---
ADDONS=()
VISIBILITY="public"
NO_INSTALL=false
TARGET_DIR=""
PROJECT_NAME=""

available_addons() {
  local dir
  for dir in "$TEMPLATES_DIR"/addons/*/; do
    dir="${dir%/}"
    printf '%s ' "${dir##*/}"
  done
}

# --- Usage ---
usage() {
  cat <<EOF
Usage: $0 <project-name> [target-dir] [--addon <name>]... [--visibility public|private]

Arguments:
  project-name    Name for the new project: lowercase letters, digits and
                  hyphens, starting with a letter
  target-dir      Directory to create (default: ./<project-name>)

Options:
  --addon         Add an addon on top of the base. Repeat for more than one.
                  Available: $(available_addons)
  --visibility    Repository visibility (default: public)
                  public:  includes code scanning workflows
                  private: leaves out what needs code scanning
  --no-install    Skip each addon's install steps (used by verify.sh)
  -h, --help      Show this help message
EOF
  exit 0
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --addon)
      ADDONS+=("$2")
      shift 2
      ;;
    --visibility)
      VISIBILITY="$2"
      if [[ "$VISIBILITY" != "public" && "$VISIBILITY" != "private" ]]; then
        echo "Error: --visibility must be 'public' or 'private'" >&2
        exit 1
      fi
      shift 2
      ;;
    --no-install)
      NO_INSTALL=true
      shift
      ;;
    -h | --help)
      usage
      ;;
    -*)
      echo "Error: Unknown option $1" >&2
      usage
      ;;
    *)
      if [[ -z "$PROJECT_NAME" ]]; then
        PROJECT_NAME="$1"
      elif [[ -z "$TARGET_DIR" ]]; then
        TARGET_DIR="$1"
      else
        echo "Error: Unexpected argument $1" >&2
        usage
      fi
      shift
      ;;
  esac
done

if [[ -z "$PROJECT_NAME" ]]; then
  echo "Error: project-name is required" >&2
  usage
fi

# The name lands in package.json, in sed replacements and in the GitHub repo
# name, so anything outside this set is refused before a file is written.
if [[ ! "$PROJECT_NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Error: project name '$PROJECT_NAME' must be lowercase letters, digits and hyphens, starting with a letter" >&2
  exit 1
fi

TARGET_DIR="${TARGET_DIR:-./$PROJECT_NAME}"

# --- Resolve addons ---
RESOLVED=""
if ((${#ADDONS[@]} > 0)); then
  RESOLVED="$(resolve_addons "${ADDONS[@]}")" || exit 1
fi
ADDONS=()
if [[ -n "$RESOLVED" ]]; then
  mapfile -t ADDONS <<<"$RESOLVED"
fi

COMMONS=()
if ((${#ADDONS[@]} > 0)); then
  COMMON_LIST="$(resolve_common "${ADDONS[@]}")"
  if [[ -n "$COMMON_LIST" ]]; then
    mapfile -t COMMONS <<<"$COMMON_LIST"
  fi
fi

# --- Check target doesn't already exist ---
if [[ -d "$TARGET_DIR" ]]; then
  echo "Error: Target directory '$TARGET_DIR' already exists" >&2
  exit 1
fi

# --- Resolve placeholders ---
GITHUB_OWNER="$(gh api user -q .login 2>/dev/null || echo "${USER:-unknown}")"
YEAR="$(date +%Y)"
if ((${#ADDONS[@]} > 0)); then
  PROJECT_DESCRIPTION="A new ${ADDONS[*]} project"
else
  PROJECT_DESCRIPTION="A new project"
fi
CODEQL_LANGUAGES="$(codeql_languages "$VISIBILITY" "${ADDONS[@]}")"

echo "Creating project '$PROJECT_NAME'..."
echo "  Target:     $TARGET_DIR"
echo "  Owner:      $GITHUB_OWNER"
echo "  Visibility: $VISIBILITY"
echo "  Addons:     ${ADDONS[*]:-none}"

# --- Copy files ---
mkdir -p "$TARGET_DIR"

copy_tree() {
  if [[ -d "$1" ]]; then
    cp -r "$1/." "$TARGET_DIR/"
  fi
}

copy_tree "$TEMPLATES_DIR/base/files"
if [[ "$VISIBILITY" == "public" ]]; then
  copy_tree "$TEMPLATES_DIR/base/public"
fi
for common in "${COMMONS[@]}"; do
  copy_tree "$TEMPLATES_DIR/common/$common/files"
done
for addon in "${ADDONS[@]}"; do
  copy_tree "$(addon_dir "$addon")/files"
done
if [[ "$VISIBILITY" == "public" ]]; then
  for addon in "${ADDONS[@]}"; do
    copy_tree "$(addon_dir "$addon")/public"
  done
fi

# --- Generate the files several addons contribute to ---
mkdir -p "$TARGET_DIR/.github"
build_gitignore "$TARGET_DIR/.gitignore" "${ADDONS[@]}"
merge_renovate "$TARGET_DIR/renovate.json" "${ADDONS[@]}"
build_codecov "$TARGET_DIR/codecov.yml" "${ADDONS[@]}"
write_manifest "$TARGET_DIR/.github/repo-standards.json" "$VISIBILITY" "${ADDONS[@]}"

# --- Replace placeholders ---
# Lines between "# >>> public" and "# <<< public" need code scanning, so a
# private scaffold drops them; a public one keeps them without the markers.
if [[ "$VISIBILITY" == "public" ]]; then
  MARKER_EDIT='/# >>> public$/d; /# <<< public$/d'
else
  MARKER_EDIT='/# >>> public$/,/# <<< public$/d'
fi
find "$TARGET_DIR" -type f | while read -r file; do
  # Skip binary files (grep -qI returns false for binary)
  if grep -qI '' "$file" 2>/dev/null; then
    sed -i -e "$MARKER_EDIT" \
      -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
      -e "s/{{GITHUB_OWNER}}/$GITHUB_OWNER/g" \
      -e "s/{{PROJECT_DESCRIPTION}}/$PROJECT_DESCRIPTION/g" \
      -e "s/{{YEAR}}/$YEAR/g" \
      -e "s/{{CODEQL_LANGUAGES}}/$CODEQL_LANGUAGES/g" \
      "$file"
  fi
done

# --- Initialize project ---
echo ""
cd "$TARGET_DIR"
git init -q
if [[ "$NO_INSTALL" == "false" ]]; then
  for addon in "${ADDONS[@]}"; do
    while IFS= read -r step; do
      echo "  $addon: $step"
      bash -c "$step"
    done < <(jq -r '.setup // [] | .[]' "$(addon_dir "$addon")/addon.json")
  done
fi

# --- Summary ---
echo ""
echo "Project '$PROJECT_NAME' created at $TARGET_DIR"
echo ""
echo "Next steps:"
echo "  cd $TARGET_DIR"
echo "  gh repo create $GITHUB_OWNER/$PROJECT_NAME --$VISIBILITY --source . --push"
