#!/usr/bin/env bash
set -euo pipefail

# Generates a docker-compose.yml for GitHub runners (bash replacement for the.
# previous Python script).

image_version="1.0.0"
image_name="ghcr.io/spindev/docker-gha-runner"

usage() {
	cat <<USAGE >&2
Usage: $0 [OPTIONS]

Generates a docker-compose.yml and helper files for GitHub self-hosted runners.

Options:
  --runners N           Number of runner services to generate (default: 1)
  --hostname NAME       Hostname prefix for each runner (default: docker-runner)
  --out-dir DIR         Directory to write compose and helper files (default: current directory)
  --out-file FILE       Compose filename (default: docker-compose.yml)
  --image-version VER   Image tag to use for runner image (default: 1.0.0)
  --runner-work-dir PATH     Path to mount as tmpfs in runner containers (default: _work)
  --daemon-json-source PATH  Copy an existing daemon.json from PATH into the output directory
  --env-source PATH          Copy an existing .env from PATH into the output directory
  --http-proxy URL           Set HTTP_PROXY and http_proxy in .env
  --https-proxy URL          Set HTTPS_PROXY and https_proxy in .env
  --no-proxy LIST            Set NO_PROXY and no_proxy in .env

  # Env variable helpers (will create/update .env in --out-dir)
  --runner-github-url URL   Set RUNNER_GITHUB_URL (default: https://github.com)
  --runner-reg-token TOKEN  Set RUNNER_REG_TOKEN
  --runner-org ORG          Set RUNNER_ORG
  --runner-labels LABELS    Set RUNNER_LABELS
  --runner-group GROUP      Set RUNNER_GROUP

  -h, --help            Show this help
USAGE
	exit 1
}

# Defaults
num_runners=1
hostname="docker-runner"
out_dir="$(pwd)"
out_file="docker-compose.yml"
runner_work_dir="_work"
daemon_json_source=""
env_source=""

# Env var flags (track whether user supplied them)
runner_github_url="https://github.com"
runner_github_url_set=0
runner_org=""
runner_org_set=0
runner_labels=""
runner_labels_set=0
runner_reg_token=""
runner_reg_token_set=0
runner_group=""
runner_group_set=0
runner_work_dir_set=0
http_proxy=""
http_proxy_set=0
https_proxy=""
https_proxy_set=0
no_proxy=""
no_proxy_set=0

# Parse flags
while [[ $# -gt 0 ]]; do
	case "$1" in
	--runners)
		num_runners="$2"
		shift 2
		;;
	--hostname)
		hostname="$2"
		shift 2
		;;
	--out-dir)
		out_dir="$2"
		shift 2
		;;
	--out-file)
		out_file="$2"
		shift 2
		;;
	--image-version)
		image_version="$2"
		shift 2
		;;
	--runner-work-dir)
		runner_work_dir="$2"
		runner_work_dir_set=1
		shift 2
		;;
	--daemon-json-source)
		daemon_json_source="$2"
		shift 2
		;;
	--env-source)
		env_source="$2"
		shift 2
		;;
	--runner-github-url)
		runner_github_url="$2"
		runner_github_url_set=1
		shift 2
		;;
	--runner-org)
		runner_org="$2"
		runner_org_set=1
		shift 2
		;;
	--runner-labels)
		runner_labels="$2"
		runner_labels_set=1
		shift 2
		;;
	--runner-reg-token)
		runner_reg_token="$2"
		runner_reg_token_set=1
		shift 2
		;;
	--runner-group)
		runner_group="$2"
		runner_group_set=1
		shift 2
		;;
	--http-proxy)
		http_proxy="$2"
		http_proxy_set=1
		shift 2
		;;
	--https-proxy)
		https_proxy="$2"
		https_proxy_set=1
		shift 2
		;;
	--no-proxy)
		no_proxy="$2"
		no_proxy_set=1
		shift 2
		;;
	-h | --help)
		usage
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage
		;;
	esac
done

if ! [[ "$num_runners" =~ ^[0-9]+$ ]] || [[ "$num_runners" -le 0 ]]; then
	echo "Error: --runners must be a positive integer" >&2
	exit 2
fi

# Ensure out dir exists and make absolute
mkdir -p "$out_dir"
out_dir="$(cd "$out_dir" && pwd)"

# Create daemon.json and .env in out_dir if missing
if [[ -n "$daemon_json_source" ]]; then
	if [[ -f "$daemon_json_source" ]]; then
		cp "$daemon_json_source" "$out_dir/daemon.json"
		echo "Copied daemon.json from $daemon_json_source to $out_dir/daemon.json"
	else
		echo "Warning: daemon json source '$daemon_json_source' not found; continuing" >&2
	fi
elif [[ ! -f "$out_dir/daemon.json" ]]; then
	cat >"$out_dir/daemon.json" <<'EOF'
{
  "experimental": false,
  "log-level": "info",
  "storage-driver": "overlay2"
}
EOF
	echo "Created $out_dir/daemon.json"
fi

set_or_add_env() {
	# $1 = file, $2 = key, $3 = value
	local file="$1" key="$2" value="$3"
	# Escape for sed
	local esc
	esc=$(printf '%s' "$value" | sed -e 's/[\/&]/\\&/g')
	if grep -qE "^${key}=" "$file"; then
		sed -i "s/^${key}=.*/${key}=${esc}/" "$file"
	else
		printf "%s=%s\n" "$key" "$value" >>"$file"
	fi
}

if [[ -n "$env_source" ]]; then
	if [[ -f "$env_source" ]]; then
		cp "$env_source" "$out_dir/.env"
		echo "Copied .env from $env_source to $out_dir/.env"
	else
		echo "Warning: env source '$env_source' not found; continuing" >&2
	fi
fi

if [[ ! -f "$out_dir/.env" ]]; then
	cat >"$out_dir/.env" <<EOF
# Minimum environment variables required for the GitHub runner setup
# Set RUNNER_REG_TOKEN to a registration token with appropriate scope
RUNNER_GITHUB_URL=${runner_github_url}
RUNNER_REG_TOKEN=${runner_reg_token}

RUNNER_LABELS=${runner_labels}
RUNNER_ORG=${runner_org}
RUNNER_GROUP=${runner_group}
RUNNER_WORK_DIR=${runner_work_dir}

# You can add additional variables below as needed
HTTP_PROXY=${http_proxy}
HTTPS_PROXY=${https_proxy}
NO_PROXY=${no_proxy}
http_proxy=${http_proxy}
https_proxy=${https_proxy}
no_proxy=${no_proxy}
EOF
	echo "Created $out_dir/.env"
else
	# Update existing .env only for flags provided
	if [[ $runner_github_url_set -eq 1 ]]; then set_or_add_env "$out_dir/.env" "RUNNER_GITHUB_URL" "$runner_github_url"; fi
	if [[ $runner_org_set -eq 1 ]]; then set_or_add_env "$out_dir/.env" "RUNNER_ORG" "$runner_org"; fi
	if [[ $runner_labels_set -eq 1 ]]; then set_or_add_env "$out_dir/.env" "RUNNER_LABELS" "$runner_labels"; fi
	if [[ $runner_reg_token_set -eq 1 ]]; then set_or_add_env "$out_dir/.env" "RUNNER_REG_TOKEN" "$runner_reg_token"; fi
	if [[ $runner_group_set -eq 1 ]]; then set_or_add_env "$out_dir/.env" "RUNNER_GROUP" "$runner_group"; fi
	if [[ $runner_work_dir_set -eq 1 ]]; then set_or_add_env "$out_dir/.env" "RUNNER_WORK_DIR" "$runner_work_dir"; fi
	if [[ $http_proxy_set -eq 1 ]]; then
		set_or_add_env "$out_dir/.env" "HTTP_PROXY" "$http_proxy"
		set_or_add_env "$out_dir/.env" "http_proxy" "$http_proxy"
	fi
	if [[ $https_proxy_set -eq 1 ]]; then
		set_or_add_env "$out_dir/.env" "HTTPS_PROXY" "$https_proxy"
		set_or_add_env "$out_dir/.env" "https_proxy" "$https_proxy"
	fi
	if [[ $no_proxy_set -eq 1 ]]; then
		set_or_add_env "$out_dir/.env" "NO_PROXY" "$no_proxy"
		set_or_add_env "$out_dir/.env" "no_proxy" "$no_proxy"
	fi
fi

out_file_full="$out_dir/$out_file"

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

# Write header
printf "services:\n" >"$tmpfile"

for i in $(seq 1 "$num_runners"); do
	cat >>"$tmpfile" <<EOF

    runner-$i:
      image: ${image_name}:${image_version}
      pull_policy: always
      privileged: true
      network_mode: bridge
      hostname: ${hostname}-$i
      env_file: .env
      volumes:
        - runner-data:/actions-runner/data
        - docker-data-$i:/var/lib/docker
        - type: bind
          source: daemon.json
          target: /etc/docker/daemon.json
          read_only: true
        - type: bind
          source: /etc/ssl/certs
          target: /etc/ssl/certs
          read_only: true
        - type: bind
          source: /usr/local/share/ca-certificates
          target: /usr/local/share/ca-certificates
          read_only: true
      tmpfs:
        - /actions-runner/${runner_work_dir}:exec
      restart: always
EOF
done

# Volumes section
cat >>"$tmpfile" <<EOF

volumes:
  runner-data:
EOF

for i in $(seq 1 "$num_runners"); do
	printf "  docker-data-%s:\n" "$i" >>"$tmpfile"
done

mv "$tmpfile" "$out_file_full"
echo "Wrote $out_file_full with $num_runners runners (hostname prefix: $hostname)"
