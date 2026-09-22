#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE_ONLY=false

usage() {
  cat <<'EOF'
Usage: ./deploy-observability.sh [--validate-only]

Options:
  --validate-only  Validate all Nomad jobs without deploying them.
  -h, --help       Show this help message.
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Error: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

for argument in "$@"; do
  case "$argument" in
    --validate-only)
      VALIDATE_ONLY=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown option: %s\n\n' "$argument" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_command nomad

jobs=(
  node-exporter.nomad
  loki.nomad
  prometheus.nomad
  alloy.nomad
  grafana.nomad
  traefik.nomad
)

for job in "${jobs[@]}"; do
  if [[ ! -f "$SCRIPT_DIR/$job" ]]; then
    printf 'Error: job file not found: %s\n' "$SCRIPT_DIR/$job" >&2
    exit 1
  fi
done

printf 'Validating Nomad jobs...\n'
for job in "${jobs[@]}"; do
  printf '  validate %s\n' "$job"
  nomad job validate "$SCRIPT_DIR/$job"
done

if [[ "$VALIDATE_ONLY" == true ]]; then
  printf 'Validation complete. No jobs were deployed.\n'
  exit 0
fi

printf 'Deploying Nomad jobs...\n'
for job in "${jobs[@]}"; do
  printf '\n==> Deploying %s\n' "$job"
  nomad job run "$SCRIPT_DIR/$job"
done

printf '\nDeployment complete. Current job status:\n'
for job in "${jobs[@]}"; do
  job_id="${job%.nomad}"
  nomad job status "$job_id" | sed -n '1,12p'
done

cat <<'EOF'

Next checks:
  consul catalog services
  curl http://127.0.0.1:3100/ready
  curl http://127.0.0.1:12345/-/ready
  curl -skI -H 'Host: grafana.balokolos.com' https://127.0.0.1/
EOF
