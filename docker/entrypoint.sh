#!/usr/bin/env bash
# shellcheck disable=SC1091
# source optional logger if available; script should continue if not present.
if [ -f /opt/bash-utils/logger.sh ]; then
	# shellcheck source=/opt/bash-utils/logger.sh
	# shellcheck disable=SC1091
	. /opt/bash-utils/logger.sh
else
	# fallback minimal logger
	INFO() { printf '[%s] [INFO] %s\n' "$(date '+%Y-%m-%d %T')" "$*"; }
	ERROR() { printf '[%s] [ERROR] %s\n' "$(date '+%Y-%m-%d %T')" "$*"; }
fi

# Parse arguments
CLEANUP=true
RETENTION_PERIOD="720h" # 30 days

while [[ "$#" -gt 0 ]]; do
	case $1 in
	--cached) CLEANUP=false ;;
	--retention)
		RETENTION_PERIOD="$2"
		shift
		;;
	*)
		INFO "Unknown parameter passed: $1"
		exit 1
		;;
	esac
	shift
done

# Function to clean up Docker artifacts
cleanup() {
	docker system prune -f --volumes
	if [[ -n "${RETENTION_PERIOD:-}" ]]; then
		docker image prune -af --filter "until=${RETENTION_PERIOD}"
	else
		docker image prune -af
	fi
	docker volume prune -af
	docker container prune -f
	docker network prune -f
}

# Function to prepare system
prepare() {
	# add certificates to java truststore
	# iterate over words in JAVA_EXTRA_CA_CERTS (assumes whitespace-separated list)
	for cert in ${JAVA_EXTRA_CA_CERTS:-}; do
		alias=$(basename "$cert")
		INFO "Importing file $cert with alias '$alias' into java keystore..."
		keytool -import -trustcacerts -cacerts \
			-storepass changeit -noprompt \
			-alias "$alias" \
			-file "$cert" || ERROR "Failed to import $cert"
	done
}

#############################################################################
#################################### RUN ####################################
#############################################################################

# Prepare System
INFO "Preparing system..."
prepare

# Start Docker
start-docker.sh
if ! start-docker.sh; then
	ERROR "Failed to start Docker daemon. Exiting."
	exit 1
fi

# Start the runner
INFO "Starting GitHub Actions runner..."
if ! start-runner.sh; then
	ERROR "Failed to start GitHub Actions runner. Exiting."
	exit 1
fi

# Perform cleanup if the CLEANUP flag is true
if [ "$CLEANUP" = true ]; then
	INFO "Cleaning up Docker daemon..."
	cleanup
else
	INFO "Skipping cleanup as --cached flag is set."
fi
