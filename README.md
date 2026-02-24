# bnode

A zero-config, self-hosted Bitcoin node stack. Full node, Electrum server, mempool explorer, Tor hidden service, and dashboard — all in one `docker compose up`.

![bnode dashboard](.github/screenshot.png)

## Why

Running a node is how you vote on the network. That shouldn't require dedicated hardware or sysadmin skills.

Most ways to run a Bitcoin node sit at one of two extremes. Projects like Umbrel, RaspiBlitz, MyNode, and Start9 are full operating systems that bundle a Bitcoin node alongside an app store and dozens of other services. They can run in a VM if you don't want to dedicate hardware, but they still carry the weight of an entire platform. On the other end, you wire everything up yourself.

`bnode` sits in the middle. It's a single Docker Compose file that runs a Bitcoin node, an Electrum server, a mempool explorer, Tor, and a dashboard, and nothing else. It works anywhere Docker runs. Clone and start.

## Quick start

```sh
sh <(curl -sL https://raw.githubusercontent.com/nachoaIvarez/bnode/master/install.sh)
```

Or manually:

```sh
git clone https://github.com/nachoaIvarez/bnode && cd bnode
docker compose up -d
```

Dashboard: [http://localhost:3110](http://localhost:3110)
Mempool explorer: [http://localhost:3109](http://localhost:3109)

## What you get

| Service | Image | Port | Description |
|---------|-------|------|-------------|
| bitcoind | Bitcoin Core | 8333 (P2P) | Full validating node with txindex |
| electrs | electrs v0.10.7 | 50001 | Electrum protocol server |
| mempool | mempool.space | 3109 | Block explorer and fee estimator |
| tor | Tor | — | SOCKS proxy + P2P hidden service |
| dashboard | Alpine + httpd | 3110 | Node status at a glance |
| mariadb | MariaDB 10.5 | — | Backend for mempool |

Most wallets speak the Electrum protocol, not bitcoind's RPC; electrs bridges that. A self-hosted mempool keeps address and transaction lookups off public sites, your ISP, and your local network. Both depend on `-txindex=1`. RPC gives full control of the node, so it stays on the internal Docker network. Tor provides a hidden service when you need remote access.

By default the node accepts connections over both clearnet and Tor, with port 8333 open so other nodes can reach you. Set `TOR_ONLY=true` to route everything through Tor instead.

## Configuration

Everything works out of the box. To customize, copy the example and edit:

```sh
cp .env.example .env
```

See [`.env.example`](.env.example) for all options including ports, Tor settings, and alternative node images. The default node is Bitcoin Core v29, the last release before the OP_RETURN policy changes in v30.

Passwords left empty are safely auto-generated on first run and stored in `data/bitcoin/secrets/.env`. Delete that file to regenerate (MariaDB data is wiped automatically to match).

## More

See [`docs/`](docs/) for architecture, advanced configuration, security model, troubleshooting, and more.

## License

[MIT](LICENSE)
