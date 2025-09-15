#!/usr/bin/env bash
set -euo pipefail

# scripts/lint.sh
# Run GitHub Super-Linter via Docker for the current repository.
# Usage: scripts/lint.sh [-o|--output <file>] [-h|--help]
# - When -o/--output is provided the full output is also saved to the file.

print_help() {
	cat <<'EOF'
Usage: lint.sh [OPTIONS]

Options:
  -f, --fix           Enable automatic fix mode for all supported linters/formatters
  -h, --help          Show this help message

Examples:
  ./scripts/lint.sh
  ./scripts/lint.sh --fix
EOF
}
FIX_MODE="false"

# Parse CLI args
while [[ $# -gt 0 ]]; do
	case "$1" in
	-f | --fix)
		FIX_MODE="true"
		shift
		;;
	-h | --help)
		print_help
		exit 0
		;;
	--)
		shift
		break
		;;
	*)
		echo "Unknown argument: $1" >&2
		print_help
		exit 2
		;;
	esac
done

# Ensure docker is available
if ! command -v docker >/dev/null 2>&1; then
	echo "docker is required but was not found on PATH. Please install/enable docker." >&2
	exit 1
fi

# Determine repo root
if git rev-parse --show-toplevel >/dev/null 2>&1; then
	REPO_DIR="$(git rev-parse --show-toplevel)"
else
	SOURCE="${BASH_SOURCE[0]}"
	while [ -h "$SOURCE" ]; do
		DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
		SOURCE="$(readlink "$SOURCE")"
		[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
	done
	SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
	REPO_DIR="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
fi

DOCKER_IMAGE="ghcr.io/super-linter/super-linter:slim-latest"

# Base env args
env_args=(-e RUN_LOCAL=true -e VALIDATE_ALL_CODEBASE=true -e DEFAULT_BRANCH=main)

# Exclude files/dirs that should not be linted by default (semrel changelogs, local dev and copilot helpers)
# - Exclude CHANGELOG.md (created by semantic-release)
# - Exclude top-level and nested `dev/` and `copilot/` directories
# Use Super-Linter's FILTER_REGEX_EXCLUDE environment variable (evaluated against file paths)
env_args+=(-e FILTER_REGEX_EXCLUDE='((^|/)(\.dev|\.copilot|super-linter-output)/|(^|/)CHANGELOG\.md$)')

if [[ "$FIX_MODE" == "true" ]]; then
	echo "Running in fix mode: Super-Linter will attempt automated fixes."
	# All known FIX_* variables from the Super-Linter docs
	fix_vars=(
		FIX_ANSIBLE FIX_CLANG_FORMAT FIX_CSHARP FIX_CSS_PRETTIER FIX_CSS
		FIX_DOTNET_SLN_FORMAT_ANALYZERS FIX_DOTNET_SLN_FORMAT_STYLE FIX_DOTNET_SLN_FORMAT_WHITESPACE
		FIX_ENV FIX_GITHUB_ACTIONS_ZIZMOR FIX_GO_MODULES FIX_GO FIX_GOOGLE_JAVA_FORMAT
		FIX_GRAPHQL_PRETTIER FIX_GROOVY FIX_HTML_PRETTIER FIX_JAVASCRIPT_ES FIX_JAVASCRIPT_PRETTIER
		FIX_JSON_PRETTIER FIX_JSON FIX_JSONC FIX_JSONC_PRETTIER FIX_JSX_PRETTIER FIX_JSX
		FIX_JUPYTER_NBQA_BLACK FIX_JUPYTER_NBQA_ISORT FIX_JUPYTER_NBQA_RUFF FIX_KOTLIN
		FIX_MARKDOWN_PRETTIER FIX_MARKDOWN FIX_NATURAL_LANGUAGE FIX_POWERSHELL FIX_PROTOBUF
		FIX_PYTHON_BLACK FIX_PYTHON_ISORT FIX_PYTHON_RUFF FIX_RUBY FIX_RUST_2015 FIX_RUST_2018
		FIX_RUST_2021 FIX_RUST_CLIPPY FIX_SCALAFMT FIX_SHELL_SHFMT FIX_SNAKEMAKE_SNAKEFMT
		FIX_SQLFLUFF FIX_TERRAFORM_FMT FIX_TSX FIX_TYPESCRIPT_ES FIX_TYPESCRIPT_PRETTIER
		FIX_VUE FIX_VUE_PRETTIER FIX_YAML_PRETTIER
	)

	for v in "${fix_vars[@]}"; do
		env_args+=(-e "${v}=true")
	done
fi

# Always save Super-Linter outputs to the workspace so we can inspect them later
env_args+=(-e SAVE_SUPER_LINTER_OUTPUT=true -e SAVE_SUPER_LINTER_SUMMARY=true)

# Final docker command (single definition) — build after env_args are finalized
cmd=(docker run --rm "${env_args[@]}" -v "$REPO_DIR":/tmp/lint -w /tmp/lint "$DOCKER_IMAGE")

# Run Super-Linter and stream output directly to the terminal
"${cmd[@]}"
exit_code=$?

echo "Super-Linter finished with exit code: $exit_code"
exit $exit_code
