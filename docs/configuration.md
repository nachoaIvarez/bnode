# Configuration

Everything works out of the box. To customize, copy the example and edit:

```sh
cp .env.example .env
```

See [`.env.example`](../.env.example) for all available options.

## Tor-only mode

Route all Bitcoin traffic exclusively through Tor, with no clearnet connections:

```sh
# in .env
TOR_ONLY=true
```

This sets `-onlynet=onion -proxy=tor:9050` on bitcoind. The node will only connect to `.onion` peers.

## Remote RPC via Tor

Expose bitcoind's RPC port as a Tor hidden service for remote access:

```sh
# in .env
EXPOSE_RPC_TOR=true
```

After restart, the `.onion` address appears in:

```
data/bitcoin/tor/bitcoin-rpc/hostname
```

Connect from any machine with Tor:

```sh
bitcoin-cli -rpcconnect=<onion-address> -rpcport=8332 \
  -rpcuser=<user> -rpcpassword=<pass> getblockchaininfo
```

## Regenerating a .onion address

Stop tor and bitcoind, delete the hidden service directory, and restart:

```sh
docker compose stop tor bitcoind
rm -rf data/bitcoin/tor/bitcoin-p2p/
docker compose up -d
```

Tor generates a fresh keypair on startup. Hidden service keys persist across container recreations as long as the volume is preserved.

## Wallet connection

Point any Electrum-compatible wallet to `localhost:50001` (or your server's IP/hostname).

For remote access over Tor, configure your wallet's SOCKS proxy to point at the Tor instance, then connect to the Electrum port on the node's `.onion` address.

### TLS for Electrum (Tailscale)

Some wallets (e.g. Bitkey) require TLS for Electrum connections. If you use Tailscale, you can terminate TLS with:

```sh
tailscale serve --bg --tls-terminated-tcp=50002 tcp://localhost:50001
```

This persists across reboots and exposes the Electrum server over TLS on port 50002 within your tailnet.

## Updating

```sh
git pull && docker compose pull && docker compose up -d
```

## Backups

Back up these directories — everything else can be re-synced:

- `data/bitcoin/secrets/` (RPC and database credentials)
- `data/bitcoin/tor/` (hidden service keys, your `.onion` addresses)
