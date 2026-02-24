#!/bin/sh

AUTH=$(echo -n "$RPC_USER:$RPC_PASSWORD" | base64)

rpc() {
  curl -sf --max-time 5 \
    -H "Authorization: Basic $AUTH" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"1.0\",\"method\":\"$1\",\"params\":[$2]}" \
    http://bitcoind:8332/ 2>/dev/null
}

# bitcoind
BTC_RAW=$(rpc getblockchaininfo)

if [ -z "$BTC_RAW" ]; then
  BTC_STATUS="unreachable"
  BTC_BLOCKS=0; BTC_HEADERS=0; BTC_PROGRESS=0; BTC_PEERS=0
  BTC_PEERS_IN=0; BTC_PEERS_OUT=0; BTC_MSG=""; BTC_CHAIN="n/a"
  BTC_DIFFICULTY=0; BTC_SIZE=0
  MEM_TX=0; MEM_VSIZE=0; MEM_FEES=0
  NET_HASHRATE=0; NET_VERSION=""; BTC_UPTIME=0
elif echo "$BTC_RAW" | jq -e '.error != null' > /dev/null 2>&1; then
  BTC_MSG=$(echo "$BTC_RAW" | jq -r '.error.message // "unknown error"')
  BTC_STATUS="loading"
  BTC_BLOCKS=0; BTC_HEADERS=0; BTC_PROGRESS=0; BTC_PEERS=0
  BTC_PEERS_IN=0; BTC_PEERS_OUT=0; BTC_CHAIN="n/a"
  BTC_DIFFICULTY=0; BTC_SIZE=0
  MEM_TX=0; MEM_VSIZE=0; MEM_FEES=0
  NET_HASHRATE=0; NET_VERSION=""; BTC_UPTIME=0
else
  BTC_BLOCKS=$(echo "$BTC_RAW" | jq -r '.result.blocks // 0')
  BTC_HEADERS=$(echo "$BTC_RAW" | jq -r '.result.headers // 0')
  BTC_PROGRESS=$(echo "$BTC_RAW" | jq -r '.result.verificationprogress // 0')
  BTC_CHAIN=$(echo "$BTC_RAW" | jq -r '.result.chain // "main"')
  BTC_DIFFICULTY=$(echo "$BTC_RAW" | jq -r '.result.difficulty // 0')
  BTC_SIZE=$(echo "$BTC_RAW" | jq -r '.result.size_on_disk // 0')
  BTC_MSG=""

  if [ "$BTC_BLOCKS" = "$BTC_HEADERS" ] && [ "$BTC_HEADERS" -gt 0 ] 2>/dev/null; then
    BTC_STATUS="ok"
  else
    BTC_STATUS="syncing"
  fi

  # peers
  PEER_RAW=$(rpc getpeerinfo)
  BTC_PEERS=$(echo "$PEER_RAW" | jq -r '.result | length // 0')
  BTC_PEERS_IN=$(echo "$PEER_RAW" | jq -r '[.result[] | select(.inbound == true)] | length // 0')
  BTC_PEERS_OUT=$(echo "$PEER_RAW" | jq -r '[.result[] | select(.inbound == false)] | length // 0')

  # mempool
  MEM_RAW=$(rpc getmempoolinfo)
  MEM_TX=$(echo "$MEM_RAW" | jq -r '.result.size // 0')
  MEM_VSIZE=$(echo "$MEM_RAW" | jq -r '.result.bytes // 0')
  MEM_FEES=$(echo "$MEM_RAW" | jq -r '.result.total_fee // 0')

  # network info
  NET_RAW=$(rpc getnetworkinfo)
  NET_VERSION=$(echo "$NET_RAW" | jq -r '.result.subversion // ""')

  # hashrate (estimate from difficulty)
  NET_HASHRATE=$(echo "$BTC_DIFFICULTY" | awk '{printf "%.0f", $1 * 4295032833.0 / 600}')

  # uptime
  UPTIME_RAW=$(rpc uptime)
  BTC_UPTIME=$(echo "$UPTIME_RAW" | jq -r '.result // 0')
fi

# electrs
ELECTRS_CHECK=$(echo '{"id":0,"method":"server.version","params":["health","1.4"]}' | nc -w3 electrs ${ELECTRUM_PORT:-50001} 2>/dev/null)
if echo "$ELECTRS_CHECK" | grep -q "result"; then
  ELECTRS_STATUS="ok"
  ELECTRS_TIP_RAW=$(echo '{"id":1,"method":"blockchain.headers.subscribe","params":[]}' | nc -w3 electrs ${ELECTRUM_PORT:-50001} 2>/dev/null)
  ELECTRS_TIP=$(echo "$ELECTRS_TIP_RAW" | jq -r '.result.height // 0' 2>/dev/null)
  [ -z "$ELECTRS_TIP" ] && ELECTRS_TIP=0
elif nc -z -w2 electrs ${ELECTRUM_PORT:-50001} 2>/dev/null; then
  ELECTRS_STATUS="loading"
  ELECTRS_TIP=0
else
  ELECTRS_STATUS="unreachable"
  ELECTRS_TIP=0
fi

# mempool web
MEMPOOL_TIP=$(curl -sf --max-time 3 http://web:8080/api/blocks/tip/height 2>/dev/null)
if [ -n "$MEMPOOL_TIP" ] && [ "$MEMPOOL_TIP" -gt 0 ] 2>/dev/null; then
  MEMPOOL_STATUS="ok"
else
  MEMPOOL_STATUS="unreachable"
  MEMPOOL_TIP=0
fi

# tor
ONION=$(cat /tor/hostname 2>/dev/null)
if [ -n "$ONION" ]; then
  TOR_STATUS="ok"
else
  TOR_STATUS="unreachable"
  ONION="n/a"
fi

# mariadb
if nc -z -w2 db 3306 2>/dev/null; then
  DB_STATUS="ok"
else
  DB_STATUS="unreachable"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p /www/api
cat > /www/api/health.json << JSONEOF
{
  "timestamp": "$TIMESTAMP",
  "services": {
    "bitcoind": {
      "status": "$BTC_STATUS",
      "blocks": $BTC_BLOCKS,
      "headers": $BTC_HEADERS,
      "progress": $BTC_PROGRESS,
      "peers": $BTC_PEERS,
      "peers_inbound": $BTC_PEERS_IN,
      "peers_outbound": $BTC_PEERS_OUT,
      "message": "$BTC_MSG",
      "chain": "$BTC_CHAIN",
      "difficulty": $BTC_DIFFICULTY,
      "hashrate": $NET_HASHRATE,
      "size_on_disk": $BTC_SIZE,
      "version": "$NET_VERSION",
      "uptime": $BTC_UPTIME,
      "mempool_tx": $MEM_TX,
      "mempool_vsize": $MEM_VSIZE,
      "mempool_fees": $MEM_FEES
    },
    "electrs": { "status": "$ELECTRS_STATUS", "tip": $ELECTRS_TIP },
    "mempool": { "status": "$MEMPOOL_STATUS", "tip": $MEMPOOL_TIP },
    "tor": { "status": "$TOR_STATUS", "address": "$ONION" },
    "mariadb": { "status": "$DB_STATUS" }
  }
}
JSONEOF
