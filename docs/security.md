# Security model

## Network isolation

All services run on a private Docker bridge network (`172.28.0.0/16`). Only four ports are exposed to the host: P2P (8333), Electrum (50001), mempool (3109), and dashboard (3110).

## RPC access

bitcoind's RPC interface only accepts connections from within the Docker network CIDR. It is never exposed to the host or the internet. To access RPC remotely, enable `EXPOSE_RPC_TOR` for a Tor hidden service (see [configuration](configuration.md)).

## Container hardening

- **Read-only filesystems**: Most containers run with `read_only: true`, limiting writable paths to explicit bind mounts and tmpfs. Exceptions: the dashboard (installs lightweight packages via `apk add`), mempool API and mempool web (their upstream images use `sed -i` to template config files at startup).
- **No privilege escalation**: Every container sets `no-new-privileges`, preventing processes from gaining elevated privileges after start.
- **Privilege dropping**: Containers that require root for initialization (chown, package install) drop to unprivileged users before running the main process: `nobody` (65534) for the dashboard, UID 1000 for electrs and mempool API.

## Secrets

RPC and database credentials are auto-generated on first boot using 128 bits of entropy from `/dev/urandom`, the kernel's cryptographically secure PRNG (ChaCha20-based on modern kernels). They are stored in `data/bitcoin/secrets/.env` with mode 600.

Deleting `secrets/.env` triggers automatic regeneration on next start. MariaDB data is wiped in this case to prevent credential mismatch (the mempool index will rebuild).

## Image pinning

All images are pinned to specific version tags to prevent supply-chain drift. See the `image:` directives in `docker-compose.yml`.
