check=false
if [ "${1:-}" = "--check" ]; then
  check=true
fi

charts_attr=".#nixosConfigurations.freia.config.services.k3s.autoDeployCharts"
stale=false

mapfile -t charts < <(nix eval --json "$charts_attr" --apply builtins.attrNames | jq -r '.[]')
for chart in "${charts[@]}"; do
  if out=$(nix build --no-link "$charts_attr.$chart.package" 2>&1); then
    continue
  fi
  specified=$(grep -oP 'specified:\s+\Ksha256-\S+' <<<"$out" || true)
  got=$(grep -oP 'got:\s+\Ksha256-\S+' <<<"$out" || true)
  if [ -z "$specified" ] || [ -z "$got" ]; then
    echo "$out" >&2
    exit 1
  fi
  echo "$chart: $specified -> $got"
  stale=true
  if [ "$check" = true ]; then
    continue
  fi
  mapfile -t files < <(grep -rlF "$specified" modules || true)
  if [ ${#files[@]} -eq 0 ]; then
    echo "$chart: stale hash $specified not found under modules/" >&2
    exit 1
  fi
  sed -i "s|$specified|$got|g" "${files[@]}"
done

if [ "$check" = true ] && [ "$stale" = true ]; then
  echo "Chart hashes are stale, run: nix run .#fix-chart-hashes" >&2
  exit 1
fi
