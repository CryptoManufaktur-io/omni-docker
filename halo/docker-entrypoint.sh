#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" = '0' ]; then
  chown -R halo:halo /halo
  exec su-exec halo docker-entrypoint.sh "$@"
fi

if [[ ! -f /halo/config/halo.toml ]]; then
  echo "Downloading halo.toml config file"
  wget https://raw.githubusercontent.com/omni-network/omni/refs/heads/main/halo/config/testdata/default_halo.toml -O /halo/config/halo.toml
fi

dasel put -f /halo/config/halo.toml -v ${NETWORK} network
dasel put -f /halo/config/halo.toml -v http://omni_evm:8551 engine-endpoint
dasel put -f /halo/config/halo.toml -v /geth/jwtsecret/jwtsecret engine-jwt-file

if [[ ! -f /halo/config/config.toml ]]; then
  echo "Downloading CometBFT config.toml file"
  wget https://raw.githubusercontent.com/omni-network/omni/refs/heads/main/halo/cmd/testdata/default_config.toml -O /halo/config/config.toml

  echo "Downloading peers list"
  wget "https://raw.githubusercontent.com/omni-network/omni/refs/heads/main/lib/netconf/${NETWORK}/consensus-seeds.txt" -O /halo/config/seeds.txt

  __persistent_peers=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    __persistent_peers+="$line,"
    echo "$line"
  done < "/halo/config/seeds.txt"

  dasel put -f /halo/config/config.toml -v "${__persistent_peers%,}" p2p.persistent_peers
fi

dasel put -f /halo/config/config.toml -v ${MONIKER} moniker

if [[ ! -f /halo/config/genesis.json ]]; then
  echo "Downloading genesis file"
  wget "https://raw.githubusercontent.com/omni-network/omni/refs/heads/main/lib/netconf/${NETWORK}/consensus-genesis.json" -O /halo/config/genesis.json
fi

# Word splitting is desired for the command line parameters
# shellcheck disable=SC2086
exec "$@" ${CL_EXTRAS}
