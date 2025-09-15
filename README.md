# Docker Runner

[![Release Application](https://github.com/xpirit-training/docker-runner/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/xpirit-training/docker-runner/actions/workflows/release.yml)

Self-hosted GitHub Actions runner that bridges the gap between traditional VM-based runners and GitHub's Actions Runner Controller (ARC) in Kubernetes. Provides Docker-in-Docker support with easy deployment via Docker Compose.

## Quick Start

1. **Generate deployment files:**

   ```bash
   ./scripts/bootstrap.sh --runner-reg-token "your-token" --runner-org "your-org"
   ```

   > Note: the `--runner-org` argument accepts either an organization name for org-level runners (e.g. `my-org`) or the `org/repo` form when you want to register a runner for a specific repository (e.g. `my-org/my-repo`).

2. **Start the runners:**

   ```bash
   docker compose up -d
   ```

3. **Scale runners (optional):**
   ```bash
   ./scripts/bootstrap.sh --runners 3 --runner-reg-token "your-token" --runner-org "your-org"
   docker compose up -d
   ```

## Production Setup

For production use, run the bootstrap script from a secure host and provide required secrets via an environment file or a secrets manager rather than on the command line. Typical production considerations:

- Choose an appropriate `--runners` count for your workload and use `--hostname`/`--runner-labels` to identify groups of runners.
- If you use Docker-in-Docker, ensure the runner containers have the required privileges and mount a persistent volume for Docker's storage (for example `/var/lib/docker`) so images and layers survive restarts.
- Configure HTTP/HTTPS proxies and `--no-proxy` if your environment requires them.
- Run the stack with `docker compose up -d` and consider running Compose under a process supervisor (systemd) for automatic restarts and log collection.
- Add monitoring and log aggregation (Prometheus, Grafana, ELK, or your preferred stack) and enable health checks for the runner containers.

Example production bootstrap command:

```bash
   ./scripts/bootstrap.sh \
      --runners "runner-count" \
      --runner-reg-token "your-token" \
      --runner-org "your-org" \
      --runner-labels "your-labels" \
      --hostname "runner-name" \
      --http-proxy "http-proxy" \
      --https-proxy "https-proxy" \
      --no-proxy "no-proxy"
```

## Bootstrap Script Options

The `bootstrap.sh` script generates a `docker-compose.yml` and `.env` file with these options:

| Option                     | Description                   | Default              |
| -------------------------- | ----------------------------- | -------------------- |
| `--runners N`              | Number of runner instances    | 1                    |
| `--hostname NAME`          | Hostname prefix for runners   | docker-runner        |
| `--runner-github-url URL`  | GitHub server URL             | <https://github.com> |
| `--runner-reg-token TOKEN` | Registration token (required) | -                    |
| `--runner-org ORG`         | Organization name             | -                    |
| `--runner-labels LABELS`   | Custom runner labels          | -                    |
| `--runner-group GROUP`     | Runner group                  | -                    |
| `--http-proxy URL`         | HTTP proxy URL                | -                    |
| `--https-proxy URL`        | HTTPS proxy URL               | -                    |
| `--no-proxy LIST`          | No proxy hosts list           | -                    |

## Demo

1. Create a [new runner](https://github.com/xpirit-training/docker-runner/settings/actions/runners/new)

2. Setup runners:

   ```bash
   # clear all volumes
   docker volume prune -af

   # set token
   TOKEN=<token>

   # setup test runners
   ./scripts/bootstrap.sh \
      --runner-reg-token ${TOKEN} \
      --runners 6 \
      --runner-org xpirit-training/docker-runner
   ```

3. Check [runners](https://github.com/xpirit-training/docker-runner/settings/actions/runners)

4. Start [test workflow](https://github.com/xpirit-training/docker-runner/actions/workflows/runner-test.yml)

## Development

```bash
# Lint all files
./scripts/lint.sh

# Lint and auto-fix issues
./scripts/lint.sh --fix
```
