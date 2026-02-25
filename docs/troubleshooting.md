# Troubleshooting

## Services show "unhealthy"

Check logs for the specific service:

```sh
docker compose logs <service>
```

Common causes: insufficient disk space, port conflicts, or slow initial sync.

## bitcoind shows error code -28

This means the node is still loading (block index, chain state, wallet). RPC is up but not accepting commands yet. This is normal after every restart and can last several minutes depending on chain size. All dependent services will show errors until this clears. The dashboard displays the loading state automatically.

## Electrs crash-loops during startup

Electrs requires bitcoind's RPC to be fully responsive. During the initial load phase (error -28), electrs will fail and restart repeatedly. This is expected — `restart: on-failure` ensures it keeps trying until bitcoind is ready.

On first run, electrs also needs bitcoind to be fully synced before indexing can begin. The health check `start_period` is set to 10 minutes. Full indexing after sync can take several additional hours.

## MariaDB won't start after secret regeneration

This is handled automatically. Deleting `secrets/.env` triggers a MariaDB data wipe on next start so credentials stay consistent. If issues persist, manually remove the database files and restart:

```sh
rm -rf data/bitcoin/mempool-db/*
docker compose up -d
```

## Dashboard shows "unreachable"

Normal during startup. The dashboard polls bitcoind's RPC every second and updates automatically once the node is ready. This can take a few minutes after a cold start.

## Dashboard has startup latency

The dashboard container installs lightweight packages (`curl`, `jq`, `busybox-extras`, `su-exec`) via `apk add` on every start. This adds a few seconds of startup latency and requires network access. This is a deliberate tradeoff to avoid maintaining a custom image.

## Inspecting processes in minimal containers

Some images (like bitcoind) don't include `ps`, `top`, or other debugging tools. To inspect the running process:

```sh
docker exec <container> cat /proc/1/cmdline | tr '\0' ' '
```

Empty output means the binary ran with no arguments, not that it's missing.

## debug.log grows large

`bitcoind/debug.log` is not rotated by default. To limit its size, add `-shrinkdebugfile` to bitcoind's arguments, or set up external log rotation on the host.

## Data directory

All persistent data lives under `${DATA_DIR}/bitcoin/` (default `./data/bitcoin/`):

```
data/bitcoin/
  bitcoind/       blockchain data, wallet, debug.log
  tor/            hidden service keys
  electrs/        electrum index
  mempool-api/    mempool backend cache
  mempool-db/     mariadb database files
  secrets/        auto-generated credentials
```

## Multi-arch

All images support `amd64` and `arm64` (Apple Silicon, Raspberry Pi 4+). No configuration changes needed.
