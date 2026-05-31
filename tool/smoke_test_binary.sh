#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage: tool/smoke_test_binary.sh PATH_TO_AMBIENT

Run a clean-workspace smoke test against a compiled ambient binary.
EOF
}

if [ $# -ne 1 ]; then
  usage >&2
  exit 64
fi

binary_path=$1
if [ ! -f "$binary_path" ]; then
  echo "Binary not found at $binary_path." >&2
  exit 66
fi

if [ ! -x "$binary_path" ]; then
  echo "Binary at $binary_path is not executable." >&2
  exit 66
fi

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/ambient-binary-smoke.XXXXXX")
cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT INT TERM

decode_base64() {
  if printf '' | base64 -d >/dev/null 2>&1; then
    base64 -d
  else
    base64 -D
  fi
}

png_base64='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGMR0bD5DwACWAF8l7vBtgAAAABJRU5ErkJggg=='
png_sha256='4fef82ec134727ea5fad48e7f083b59c208cac3b07007021f80e5199af96a246'
run_dir="$work_dir/run"
report_dir="$work_dir/report"
config_path="$work_dir/ambient.config.yaml"
manifest_path="$run_dir/manifest.json"
image_path="$run_dir/captures/button-primary.png"

mkdir -p "$run_dir/captures"
printf '%s' "$png_base64" | decode_base64 > "$image_path"

cat > "$config_path" <<'EOF'
adapters:
  - platform: flutter
    projectPath: ./
storage:
  backend: local
  path: .ambient/baselines
compare:
  threshold: 0.1
EOF

cat > "$manifest_path" <<EOF
{
  "manifestVersion": "1.0",
  "entries": [
    {
      "id": "button-primary::flutter",
      "platform": "flutter",
      "width": 1,
      "height": 1,
      "dpr": 1,
      "contentHash": "$png_sha256",
      "envFingerprint": "ambient/smoke",
      "imagePath": "captures/button-primary.png"
    }
  ]
}
EOF

"$binary_path" --version >/dev/null

set +e
"$binary_path" test \
  --config "$config_path" \
  --run-dir "$run_dir" \
  --report-dir "$report_dir"
first_test_exit=$?
set -e

if [ "$first_test_exit" -ne 1 ]; then
  echo "Expected the first ambient test run to exit 1 for a new snapshot, got $first_test_exit." >&2
  exit 1
fi

if [ ! -f "$report_dir/report.html" ]; then
  echo "Expected ambient test to write $report_dir/report.html." >&2
  exit 1
fi

"$binary_path" accept --config "$config_path" --run-dir "$run_dir"
"$binary_path" test \
  --config "$config_path" \
  --run-dir "$run_dir" \
  --report-dir "$report_dir"

printf 'Standalone binary smoke test passed: %s\n' "$binary_path"
