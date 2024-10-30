#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" = '0' ]; then
  chown -R geth:geth /var/lib/geth
  exec su-exec geth docker-entrypoint.sh "$@"
fi

if [ -n "${JWT_SECRET}" ]; then
  echo -n "${JWT_SECRET}" > /var/lib/geth/ee-secret/jwtsecret
  echo "JWT secret was supplied in .env"
fi

if [[ ! -f /var/lib/geth/ee-secret/jwtsecret ]]; then
  echo "Generating JWT secret"
  __secret1=$(head -c 8 /dev/urandom | od -A n -t u8 | tr -d '[:space:]' | sha256sum | head -c 32)
  __secret2=$(head -c 8 /dev/urandom | od -A n -t u8 | tr -d '[:space:]' | sha256sum | head -c 32)
  echo -n "${__secret1}""${__secret2}" > /var/lib/geth/ee-secret/jwtsecret
fi

if [[ -O "/var/lib/geth/ee-secret" ]]; then
  # In case someone specifies JWT_SECRET but it's not a distributed setup
  chmod 777 /var/lib/geth/ee-secret
fi
if [[ -O "/var/lib/geth/ee-secret/jwtsecret" ]]; then
  chmod 666 /var/lib/geth/ee-secret/jwtsecret
fi

__ancient=""

if [ -n "${ANCIENT_DIR}" ] && [ ! "${ANCIENT_DIR}" = ".nada" ]; then
  echo "Using separate ancient directory at ${ANCIENT_DIR}."
  __ancient="--datadir.ancient /var/lib/ancient"
fi

wget "https://raw.githubusercontent.com/omni-network/omni/refs/heads/main/lib/netconf/${NETWORK}/execution-genesis.json" -O /home/geth/genesis.json
wget "https://raw.githubusercontent.com/omni-NETWORK/omni/refs/heads/main/lib/netconf/${NETWORK}/execution-seeds.txt" -O /home/geth/bootnode.txt
wget https://raw.githubusercontent.com/omni-network/omni/refs/heads/main/e2e/app/geth/testdata/default_config.toml -O /home/geth/config.toml

dasel delete -f /home/geth/config.toml Node.DataDir
dasel delete -f /home/geth/config.toml Node.IPCPath
dasel delete -f /home/geth/config.toml Node.HTTPHost
dasel delete -f /home/geth/config.toml Node.HTTPVirtualHosts

__config="--config /home/geth/config.toml"

networkid="$(jq -r '.config.chainId' "/home/geth/genesis.json")"
bootnodes="$(paste -s -d, "/home/geth/bootnode.txt")"

set +e
__network="--bootnodes=${bootnodes} --networkid=${networkid} --http.api=eth,net,web3,debug,admin,txpool"

if [ ! -d "/var/lib/geth/geth/chaindata/" ]; then
  geth init --datadir /var/lib/geth "/home/geth/genesis.json"
fi

__datadir="--datadir /var/lib/geth"

# Set verbosity
shopt -s nocasematch
case ${LOG_LEVEL} in
  error)
    __verbosity="--verbosity 1"
    ;;
  warn)
    __verbosity="--verbosity 2"
    ;;
  info)
    __verbosity="--verbosity 3"
    ;;
  debug)
    __verbosity="--verbosity 4"
    ;;
  trace)
    __verbosity="--verbosity 5"
    ;;
  *)
    echo "LOG_LEVEL ${LOG_LEVEL} not recognized"
    __verbosity=""
    ;;
esac

if [ "${ARCHIVE_NODE}" = "true" ]; then
  echo "Geth archive node without pruning"
  __prune="--syncmode=full --gcmode=archive"
else
  __prune=""
fi

# Word splitting is desired for the command line parameters
# shellcheck disable=SC2086
exec "$@" ${__datadir} ${__ancient} ${__network} ${__prune} ${__verbosity} ${EL_EXTRAS}
