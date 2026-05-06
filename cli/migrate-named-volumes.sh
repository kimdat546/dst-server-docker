#!/usr/bin/env bash
# One-shot migration: copies an existing world's named Docker volumes
# into ./data/{Master,Caves} (bind mounts) used by the new compose.
# Run once per world that was set up before this tooling existed.
# Usage: git checkout <branch> && ./cli/migrate-named-volumes.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OLD_MASTER_VOL="dst-server-docker_dst-master-data-myth-words"
OLD_CAVES_VOL="dst-server-docker_dst-caves-data-myth-words"

BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = "myth-words" ] || { echo "Checkout the myth-words branch first."; exit 1; }

if docker ps --format '{{.Names}}' | grep -qE '^dst-(master|caves)-myth-words$'; then
  echo "Old containers running. Stop them first:"
  echo "  cd $ROOT/server && docker compose down"
  exit 1
fi

mkdir -p "$ROOT/data/Master" "$ROOT/data/Caves"

echo "==> Master volume → $ROOT/data/Master"
docker run --rm \
  -v "$OLD_MASTER_VOL":/src:ro \
  -v "$ROOT/data/Master":/dst \
  alpine:3 sh -c 'cp -a /src/. /dst/'

echo "==> Caves volume → $ROOT/data/Caves"
docker run --rm \
  -v "$OLD_CAVES_VOL":/src:ro \
  -v "$ROOT/data/Caves":/dst \
  alpine:3 sh -c 'cp -a /src/. /dst/'

echo "==> Initialising .world.env"
"$ROOT/cli/dst" init

echo "myth-words" > "$ROOT/.dst-current"

echo
echo "Done. Verify with:  $ROOT/cli/dst start"
echo "After confirming the world boots, you can drop the old volumes:"
echo "  docker volume rm $OLD_MASTER_VOL $OLD_CAVES_VOL"
