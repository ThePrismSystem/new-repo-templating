#!/usr/bin/env bash
# The container checks. Each job in .github/workflows/docker.yml runs one
# step; run `all` locally before pushing. Needs hadolint, Trivy and Docker.

IMAGE="${IMAGE:-check-docker:local}"

usage() {
  cat <<USAGE
Usage: $0 <step>

Steps:
  lint   hadolint at warning level over every Dockerfile git doesn't ignore,
         and Trivy's misconfiguration scan
  scan   Build the image as \$IMAGE ($IMAGE) and fail on HIGH or CRITICAL
         vulnerabilities that have a fix. With SARIF_DIR set, the findings
         also go to \$SARIF_DIR/trivy-image.sarif
  all    Every step above
USAGE
}

# Untracked files count too, so a new Dockerfile is checked before it's added.
dockerfiles() {
  local file
  while IFS= read -r file; do
    if [[ -f "$file" ]]; then
      printf '%s\n' "$file"
    fi
  done < <(git ls-files --cached --others --exclude-standard -- '*Dockerfile' '*Dockerfile.*' '*.dockerfile' | sort -u)
}

step_lint() {
  local files=()
  mapfile -t files < <(dockerfiles)
  if ((${#files[@]} == 0)); then
    echo "No Dockerfiles to check."
    return 0
  fi
  hadolint --failure-threshold warning "${files[@]}"
  trivy config --quiet --exit-code 1 --skip-dirs node_modules,.venv,lua_modules,.luarocks .
}

step_scan() {
  docker build --tag "$IMAGE" .
  if [[ -n "${SARIF_DIR:-}" ]]; then
    mkdir -p "$SARIF_DIR"
    trivy image --quiet --format sarif --output "$SARIF_DIR/trivy-image.sarif" \
      --severity HIGH,CRITICAL --ignore-unfixed "$IMAGE"
  fi
  trivy image --quiet --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed "$IMAGE"
}

main() {
  set -euo pipefail
  local step="${1:-}"
  case "$step" in
    lint | scan)
      "step_$step"
      ;;
    all)
      local name
      for name in lint scan; do
        echo "-- $name"
        "step_$name"
      done
      ;;
    -h | --help)
      usage
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
