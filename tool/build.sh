#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage: tool/build.sh [--output PATH]

Compile the standalone AmbientVRT CLI binary.

Options:
  --output PATH  Output path for the compiled binary (default: ./ambient)
  -h, --help     Show this help text
EOF
}

script_dir=$(
  CDPATH= cd -- "$(dirname "$0")"
  pwd
)
repo_root=$(
  CDPATH= cd -- "$script_dir/.."
  pwd
)
output_path="$repo_root/ambient"

while [ $# -gt 0 ]; do
  case "$1" in
    --output)
      if [ $# -lt 2 ]; then
        echo "Missing value for --output." >&2
        usage >&2
        exit 64
      fi
      output_path=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if ! command -v dart >/dev/null 2>&1; then
  echo "The Dart SDK must be available on PATH to build the ambient binary." >&2
  exit 127
fi

case "$output_path" in
  /*) ;;
  *) output_path="$repo_root/$output_path" ;;
esac

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/ambient-build.XXXXXX")
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

stage_root="$tmp_dir/stage"
mkdir -p "$stage_root/packages"
cp -R "$repo_root/packages/ambient_core" "$stage_root/packages/ambient_core"
cp -R "$repo_root/packages/ambient_cli" "$stage_root/packages/ambient_cli"

strip_workspace_resolution() {
  file_path=$1
  temp_path="$file_path.tmp"
  awk '$0 != "resolution: workspace" { print }' "$file_path" > "$temp_path"
  mv "$temp_path" "$file_path"
}

strip_workspace_resolution "$stage_root/packages/ambient_core/pubspec.yaml"
strip_workspace_resolution "$stage_root/packages/ambient_cli/pubspec.yaml"

mkdir -p "$(dirname "$output_path")"
(
  cd "$stage_root/packages/ambient_cli"
  dart pub get
  dart compile exe bin/ambient.dart -o "$output_path"
)
chmod +x "$output_path"

printf 'Built standalone ambient binary at %s\n' "$output_path"
