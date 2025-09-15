#!/usr/bin/env bash
# Logger utilities
# Lightweight, bash-only logger that prints timestamp, level and message.

INFO() {
	local msg="$1"
	local timeAndDate
	timeAndDate=$(date '+%Y-%m-%d %T')
	printf '[%s] [INFO] [%s] %s\n' "$timeAndDate" "$(basename "${BASH_SOURCE[1]:-$0}")" "$msg"
}

DEBUG() {
	local msg="$1"
	local timeAndDate
	timeAndDate=$(date '+%Y-%m-%d %T')
	printf '[%s] [DEBUG] [%s] %s\n' "$timeAndDate" "$(basename "${BASH_SOURCE[1]:-$0}")" "$msg"
}

ERROR() {
	local msg="$1"
	local timeAndDate
	timeAndDate=$(date '+%Y-%m-%d %T')
	printf '[%s] [ERROR] [%s] %s\n' "$timeAndDate" "$(basename "${BASH_SOURCE[1]:-$0}")" "$msg"
}
