#!/bin/bash
source /opt/bash-utils/logger.sh

# Function to wait for a specific process to start running
function wait_for_process() {
	local max_time_wait=30
	local process_name="$1"
	local waited_sec=0
	while ! pgrep "$process_name" >/dev/null && ((waited_sec < max_time_wait)); do
		INFO "Process $process_name is not running yet. Retrying in 1 seconds"
		INFO "Waited $waited_sec seconds of $max_time_wait seconds"
		sleep 1
		((waited_sec = waited_sec + 1))
		if ((waited_sec >= max_time_wait)); then
			return 1
		fi
	done
	return 0
}

# Function to wait for Docker daemon to be reachable
function wait_for_docker_daemon() {
	local max_time_wait=30
	local waited_sec=0
	while ((waited_sec < max_time_wait)); do
		if docker version >/dev/null 2>&1; then
			INFO "Docker daemon is reachable"
			return 0
		fi
		INFO "Docker daemon is not reachable yet. Retrying in 1 seconds"
		INFO "Waited $waited_sec seconds of $max_time_wait seconds"
		sleep 1
		((waited_sec = waited_sec + 1))
	done
	return 1
}

# Function to configure Docker client with proxy settings
configure_docker_client_proxy() {
	if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ] || [ -n "$NO_PROXY" ]; then
		INFO "Configuring Docker client with proxy settings..."
		mkdir -p ~/.docker
		if [ -f ~/.docker/config.json ]; then
			jq '.proxies.default += {
                "httpProxy": env.HTTP_PROXY,
                "httpsProxy": env.HTTPS_PROXY,
                "noProxy": env.NO_PROXY
            }' ~/.docker/config.json >~/.docker/config.json.tmp && mv ~/.docker/config.json.tmp ~/.docker/config.json
		else
			echo '{}' | jq '.proxies.default += {
                "httpProxy": env.HTTP_PROXY,
                "httpsProxy": env.HTTPS_PROXY,
                "noProxy": env.NO_PROXY
            }' >~/.docker/config.json
		fi
	fi
}

#############################################################################
#################################### RUN ####################################
#############################################################################

# Start the supervisor process
INFO "Starting supervisor"
/usr/bin/supervisord -n >>/dev/null 2>&1 &

# Configure Docker client with proxy settings
INFO "Configuring Docker client with proxy settings"
configure_docker_client_proxy

# Wait for the Docker daemon to be running
INFO "Waiting for docker to be running"
if ! wait_for_process dockerd; then
	ERROR "dockerd is not running after max time"
	exit 1
else
	INFO "dockerd is running"
fi

# Verify Docker daemon is reachable
INFO "Verifying Docker daemon is reachable"
if ! wait_for_docker_daemon; then
	ERROR "Docker daemon is not reachable after max time"
	exit 1
else
	INFO "Docker daemon is reachable and ready"
fi
