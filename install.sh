#!/bin/sh
set -e

REPO="https://github.com/nachoaIvarez/bnode"
DIR="bnode"

echo "bnode — Bitcoin node stack"
echo ""

# --- check dependencies ---

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed."
  echo "Install it from https://docs.docker.com/get-docker/"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Error: docker compose is not available."
  echo "Install Docker Compose v2: https://docs.docker.com/compose/install/"
  exit 1
fi

# --- download ---

if [ -d "$DIR" ]; then
  echo "Directory '$DIR' already exists. Skipping download."
else
  if command -v git >/dev/null 2>&1; then
    echo "Cloning $REPO..."
    git clone --depth 1 "$REPO" "$DIR"
  else
    echo "Downloading $REPO..."
    curl -sL "$REPO/archive/refs/heads/master.tar.gz" | tar xz
    mv bnode-master "$DIR"
  fi
fi

cd "$DIR"

# --- helper ---

ask() {
  printf "  %s [%s]: " "$1" "$2" >&2
  read -r ans
  echo "${ans:-$2}"
}

# --- quick or custom ---

echo ""
printf "  Use defaults and start immediately? [Y/n]: "
read -r quick

case "$quick" in
  [nN]*) ;;
  *)
    echo ""
    echo "Summary:"
    echo ""
    echo "  Node image:        bitcoin/bitcoin:29.3"
    echo "  Data directory:    ./data"
    echo "  P2P port:          8333"
    echo "  Electrum port:     50001"
    echo "  Mempool port:      3109"
    echo "  Dashboard port:    3110"
    echo "  Tor-only mode:     false"
    echo "  Expose RPC (Tor):  false"
    echo ""
    echo "Starting bnode..."
    docker compose up -d
    echo ""
    echo "Done. Your node is starting up."
    echo ""
    echo "  Dashboard:  http://localhost:3110"
    echo "  Mempool:    http://localhost:3109"
    echo ""
    echo "Initial blockchain sync will take several hours."
    echo "Check progress at the dashboard URL above."
    exit 0
    ;;
esac

# --- step 1: node software ---

echo ""
echo "Step 1: Choose node software"
echo ""
echo "  1) Bitcoin Core v29.3 (default)"
echo "  2) Bitcoin Core v30.2"
echo "  3) Bitcoin Knots"
echo "  4) Bitcoin Knots + BIP110"
echo "  5) Custom image"
echo ""
printf "  Choice [1]: "
read -r img_choice

case "${img_choice:-1}" in
  1) BITCOIND_IMAGE="bitcoin/bitcoin:29.3" ;;
  2) BITCOIND_IMAGE="bitcoin/bitcoin:30.2" ;;
  3) BITCOIND_IMAGE="ghcr.io/retropex/bitcoin:29.3.knots20260210" ;;
  4) BITCOIND_IMAGE="ghcr.io/retropex/bitcoin:29.3.knots20260210-bip110-v0.3" ;;
  5)
    printf "  Image (e.g. org/repo:tag): "
    read -r BITCOIND_IMAGE
    if [ -z "$BITCOIND_IMAGE" ]; then
      echo "Error: no image provided."
      exit 1
    fi
    ;;
  *)
    echo "Error: invalid choice."
    exit 1
    ;;
esac

# --- step 2: configuration ---

echo ""
echo "Step 2: Configuration (press Enter to keep defaults)"
echo ""

DATA_DIR=$(ask "Data directory" "./data")
P2P_PORT=$(ask "P2P port" "8333")
ELECTRUM_PORT=$(ask "Electrum port" "50001")
MEMPOOL_PORT=$(ask "Mempool port" "3109")
DASHBOARD_PORT=$(ask "Dashboard port" "3110")
TOR_ONLY=$(ask "Tor-only mode" "false")
EXPOSE_RPC_TOR=$(ask "Expose RPC over Tor" "false")

# --- step 3: confirm ---

echo ""
echo "Summary:"
echo ""
echo "  Node image:        $BITCOIND_IMAGE"
echo "  Data directory:    $DATA_DIR"
echo "  P2P port:          $P2P_PORT"
echo "  Electrum port:     $ELECTRUM_PORT"
echo "  Mempool port:      $MEMPOOL_PORT"
echo "  Dashboard port:    $DASHBOARD_PORT"
echo "  Tor-only mode:     $TOR_ONLY"
echo "  Expose RPC (Tor):  $EXPOSE_RPC_TOR"
echo ""
printf "  Proceed? [Y/n]: "
read -r confirm

case "$confirm" in
  [nN]*) echo "Aborted."; exit 0 ;;
esac

# --- write .env ---

cat > .env << EOF
DATA_DIR=$DATA_DIR
BITCOIND_IMAGE=$BITCOIND_IMAGE
P2P_PORT=$P2P_PORT
ELECTRUM_PORT=$ELECTRUM_PORT
MEMPOOL_PORT=$MEMPOOL_PORT
DASHBOARD_PORT=$DASHBOARD_PORT
TOR_ONLY=$TOR_ONLY
EXPOSE_RPC_TOR=$EXPOSE_RPC_TOR
EOF

# --- start ---

echo ""
echo "Starting bnode..."
docker compose up -d

echo ""
echo "Done. Your node is starting up."
echo ""
echo "  Dashboard:  http://localhost:$DASHBOARD_PORT"
echo "  Mempool:    http://localhost:$MEMPOOL_PORT"
echo ""
echo "Initial blockchain sync will take several hours."
echo "Check progress at the dashboard URL above."
