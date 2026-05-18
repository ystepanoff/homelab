#!/usr/bin/env bash
# Orchestrate all homelab compose stacks.
#
# Every substack references an external docker network named `proxy`.
# That network must exist before any stack can be brought up — otherwise
# `external: true` lookups fail and Traefik ends up logging
# `Could not find network named "proxy"` for every container.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
NETWORK_NAME="proxy"

# Bring-up order. `data` (postgres/mongo/couchdb) and `net` (traefik/tailscale)
# must come up first because other stacks depend on them.
STACKS=(data net media tools domus stuff monitoring backup)

ensure_network() {
  if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "==> Creating docker network '$NETWORK_NAME'"
    docker network create "$NETWORK_NAME" >/dev/null
  fi
}

compose() {
  local stack="$1"; shift
  (cd "$ROOT_DIR/$stack" && docker compose --env-file "$ROOT_DIR/.env" "$@")
}

cmd_up() {
  ensure_network
  for stack in "${STACKS[@]}"; do
    echo "==> up: $stack"
    compose "$stack" up -d
  done
}

cmd_down() {
  for ((i=${#STACKS[@]}-1; i>=0; i--)); do
    echo "==> down: ${STACKS[i]}"
    compose "${STACKS[i]}" down
  done
}

cmd_restart() {
  cmd_down
  cmd_up
}

cmd_pull() {
  for stack in "${STACKS[@]}"; do
    echo "==> pull: $stack"
    compose "$stack" pull
  done
}

cmd_status() {
  for stack in "${STACKS[@]}"; do
    echo "==> $stack"
    compose "$stack" ps
  done
}

cmd_logs() {
  local stack="${1:-}"
  if [[ -z "$stack" ]]; then
    echo "Usage: $0 logs <stack>" >&2
    exit 1
  fi
  compose "$stack" logs -f
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") <command> [args]

Commands:
  up        Ensure '$NETWORK_NAME' network exists, then bring all stacks up
  down      Bring all stacks down (reverse order)
  restart   down + up
  pull      docker compose pull for all stacks
  status    docker compose ps for all stacks
  logs <s>  Follow logs for a single stack

Stacks (in start order): ${STACKS[*]}
USAGE
}

case "${1:-}" in
  up)      shift; cmd_up "$@" ;;
  down)    shift; cmd_down "$@" ;;
  restart) shift; cmd_restart "$@" ;;
  pull)    shift; cmd_pull "$@" ;;
  status)  shift; cmd_status "$@" ;;
  logs)    shift; cmd_logs "$@" ;;
  ""|-h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
