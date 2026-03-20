#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# --- Defaults ---
FLAVOR="typescript-node"
TARGET_DIR=""
PROJECT_NAME=""

# --- Usage ---
usage() {
  cat <<EOF
Usage: $0 <project-name> [target-dir] [--flavor typescript-node|typescript-react]

Arguments:
  project-name    Name for the new project (used in package.json, README, etc.)
  target-dir      Directory to create (default: ./<project-name>)

Options:
  --flavor        Template flavor (default: typescript-node)
                  Available: typescript-node, typescript-react
  -h, --help      Show this help message
EOF
  exit 0
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --flavor)
      FLAVOR="$2"
      shift 2
      ;;
    -h|--help)
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

TARGET_DIR="${TARGET_DIR:-./$PROJECT_NAME}"

# --- Validate flavor ---
if [[ ! -d "$TEMPLATES_DIR/$FLAVOR" ]]; then
  echo "Error: Unknown flavor '$FLAVOR'. Available flavors:" >&2
  ls -1 "$TEMPLATES_DIR" | grep -v _shared >&2
  exit 1
fi

# --- Check target doesn't already exist ---
if [[ -d "$TARGET_DIR" ]]; then
  echo "Error: Target directory '$TARGET_DIR' already exists" >&2
  exit 1
fi

# --- Resolve placeholders ---
GITHUB_OWNER="$(gh api user -q .login 2>/dev/null || echo "$USER")"
YEAR="$(date +%Y)"
NODE_VERSION="$(cat "$TEMPLATES_DIR/$FLAVOR/.nvmrc" 2>/dev/null || echo "22")"

echo "Creating project '$PROJECT_NAME' with flavor '$FLAVOR'..."
echo "  Target:  $TARGET_DIR"
echo "  Owner:   $GITHUB_OWNER"

# --- Copy files ---
mkdir -p "$TARGET_DIR"

# Copy shared files first
cp -r "$TEMPLATES_DIR/_shared/." "$TARGET_DIR/"

# Copy flavor files (overwrites any shared duplicates)
cp -r "$TEMPLATES_DIR/$FLAVOR/." "$TARGET_DIR/"

# --- Replace placeholders ---
find "$TARGET_DIR" -type f | while read -r file; do
  # Skip binary files (grep -qI returns false for binary)
  if grep -qI '' "$file" 2>/dev/null; then
    sed -i \
      -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
      -e "s/{{GITHUB_OWNER}}/$GITHUB_OWNER/g" \
      -e "s/{{PROJECT_DESCRIPTION}}/A new $FLAVOR project/g" \
      -e "s/{{YEAR}}/$YEAR/g" \
      -e "s/{{NODE_VERSION}}/$NODE_VERSION/g" \
      "$file"
  fi
done

# --- Initialize project ---
echo ""
echo "Initializing git and installing dependencies..."

cd "$TARGET_DIR"
git init -q
pnpm install
pnpm exec husky

# --- Summary ---
echo ""
echo "Project '$PROJECT_NAME' created at $TARGET_DIR"
echo ""
echo "  cd $TARGET_DIR"
echo "  pnpm dev        # Start development"
echo "  pnpm typecheck   # Type check"
echo "  pnpm lint        # Lint"
echo "  pnpm test        # Run tests"
