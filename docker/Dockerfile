#############################################################################################################################
# Base
#############################################################################################################################

FROM ubuntu:noble AS base

# Metadata
LABEL maintainer="LLI" \
  description="GitHub Actions Runner with Docker-in-Docker support"

# Set Environment Variables
ENV DEBUG=false \
  DEBIAN_FRONTEND=noninteractive

# Build arguments for versions
ARG OPENJDK_VERSION=21

# Install Common Dependencies
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  curl \
  git \
  gnupg \
  iptables \
  jq \
  libffi-dev \
  libssl-dev \
  nodejs \
  npm \
  openjdk-${OPENJDK_VERSION}-jdk \
  python3 \
  python3-dev \
  python3-pip \
  python3-venv \
  software-properties-common \
  ssh \
  supervisor \
  tree \
  unzip \
  yq \
  && \
  rm -rf /var/lib/apt/lists/*

# Move Java CA Truststore
# Enables for mounting certificates in /ets/ssl/certs
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN JAVA_HOME=$(readlink -f "$(which java)" | sed "s:/bin/java::") && \
  JAVA_VERSION=$(basename "$JAVA_HOME") && \
  SOURCE_LINK="$JAVA_HOME/lib/security/cacerts" && \
  SOURCE=$(readlink -f "$SOURCE_LINK") && \
  TARGET="/etc/${JAVA_VERSION%-*}/security/cacerts" && \
  mv "$SOURCE" "$TARGET" && \
  ln -sf "$TARGET" "$SOURCE_LINK"

#############################################################################################################################
# Download Docker
#############################################################################################################################

FROM base AS download-docker

# Build arguments for versions
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION=28.3.3
ARG DOCKER_COMPOSE_VERSION=v2.39.1
ARG BUILDX_VERSION=v0.26.1

# Set working directory for downloads
WORKDIR /downloads

# Download Docker, Compose and Buildx
RUN arch="$(uname -m)" && \
  case "$arch" in \
  x86_64) dockerArch='x86_64' ; buildx_arch='linux-amd64' ;; \
  armhf) dockerArch='armel' ; buildx_arch='linux-arm-v6' ;; \
  armv7) dockerArch='armhf' ; buildx_arch='linux-arm-v7' ;; \
  aarch64) dockerArch='aarch64' ; buildx_arch='linux-arm64' ;; \
  *) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;; \
  esac && \
  mkdir -p docker-binaries && \
  curl -fSL -o docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz" && \
  tar --extract --file docker.tgz --strip-components 1 --directory docker-binaries/ && \
  curl -fSL -o docker-buildx "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.${buildx_arch}" && \
  curl -fSL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o docker-compose && \
  chmod +x docker-buildx docker-compose

#############################################################################################################################
# Download Runner
#############################################################################################################################

FROM base AS download-runner

# Build argument for runner version
ARG RUNNER_VERSION=2.328.0

# Set working directory for downloads
WORKDIR /downloads

# Download GitHub Actions Runner
RUN curl -o actions-runner.tar.gz -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" && \
  mkdir -p actions-runner && \
  tar xzf actions-runner.tar.gz --directory actions-runner

#############################################################################################################################
# Docker
#############################################################################################################################

FROM base AS docker

# Copy downloaded files from download stages
COPY --from=download-docker /downloads/docker-binaries/* /usr/local/bin/
COPY --from=download-docker /downloads/docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx
COPY --from=download-docker /downloads/docker-compose /usr/local/bin/docker-compose

# Install Docker, Compose and Buildx
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
  mkdir -p /usr/local/lib/docker/cli-plugins && \
  dockerd --version && \
  docker --version && \
  docker buildx version && \
  docker-compose version && \
  ln -s /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

#############################################################################################################################
# Runner
#############################################################################################################################

FROM docker AS runner

# Copy GitHub Actions Runner from download stage
COPY --from=download-runner /downloads/actions-runner /actions-runner

# Setup GitHub Actions Runner
RUN mkdir -p /actions-runner/data && \
  /actions-runner/bin/installdependencies.sh

# Setup Scripts
COPY modprobe start-docker.sh start-runner.sh entrypoint.sh /usr/local/bin/
COPY dockerd.conf /etc/supervisor/conf.d/
COPY logger.sh /opt/bash-utils/logger.sh
RUN chmod +x \
  /usr/local/bin/modprobe \
  /usr/local/bin/start-docker.sh \
  /usr/local/bin/start-runner.sh \
  /usr/local/bin/entrypoint.sh

# Add healthcheck to verify Docker daemon and runner process
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD docker version >/dev/null 2>&1 && pgrep -f "Runner.Listener" >/dev/null 2>&1 || exit 1

ENTRYPOINT ["entrypoint.sh"]
