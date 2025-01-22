#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" = '0' ]; then
  chown -R halo:halo /halo
  exec su-exec halo docker-entrypoint.sh "$@"
fi

# Halo config.
if [[ ! -f /halo/config/halo.toml ]]; then
  echo "Downloading halo.toml config file"
  wget https://raw.githubusercontent.com/omni-network/omni/refs/heads/main/halo/config/testdata/default_halo.toml -O /halo/config/halo.toml
fi

dasel put -f /halo/config/halo.toml -v ${NETWORK} network
dasel put -f /halo/config/halo.toml -v ${EL_NODE} engine-endpoint
dasel put -f /halo/config/halo.toml -v /geth/jwtsecret/jwtsecret engine-jwt-file
dasel put -f /halo/config/halo.toml -v "600ms" evm-build-delay

if [ "$NETWORK" == "mainnet" ]; then
  dasel put -f /halo/config/halo.toml -v "${ARBITRUM_RPC_URL}" xchain.evm-rpc-endpoints.arbitrum_one
  dasel put -f /halo/config/halo.toml -v "${BASE_RPC_URL}" xchain.evm-rpc-endpoints.base
  dasel put -f /halo/config/halo.toml -v "${ETH_RPC_URL}" xchain.evm-rpc-endpoints.ethereum
  dasel put -f /halo/config/halo.toml -v "${OP_RPC_URL}" xchain.evm-rpc-endpoints.optimism
else
  dasel put -f /halo/config/halo.toml -v "${ARBITRUM_RPC_URL}" xchain.evm-rpc-endpoints.arb_sepolia
  dasel put -f /halo/config/halo.toml -v "${BASE_RPC_URL}" xchain.evm-rpc-endpoints.base_sepolia
  dasel put -f /halo/config/halo.toml -v "${ETH_RPC_URL}" xchain.evm-rpc-endpoints.holesky
  dasel put -f /halo/config/halo.toml -v "${OP_RPC_URL}" xchain.evm-rpc-endpoints.op_sepolia
fi

# CometBFT config.
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

dasel put -f /halo/config/config.toml -v ${MONIKER} moniker

dasel put -f /halo/config/config.toml -v "tcp://0.0.0.0:${CL_P2P_PORT}" p2p.laddr
dasel put -f /halo/config/config.toml -v "${HOST_IP}:${CL_P2P_PORT}" p2p.external_address

dasel put -f /halo/config/config.toml -v "tcp://0.0.0.0:${CL_RPC_PORT}" rpc.laddr

dasel put -f /halo/config/config.toml -v "1s" consensus.timeout_commit

# Genesis file.
if [[ ! -f /halo/config/genesis.json ]]; then
  echo "Downloading genesis file"
  wget "https://raw.githubusercontent.com/omni-network/omni/refs/heads/main/lib/netconf/${NETWORK}/consensus-genesis.json" -O /halo/config/genesis.json
fi

# Check whether we should rapid sync
if [ -n "${RAPID_SYNC_URL}" ]; then
  echo "Configuring rapid state sync"
  # Get the latest height
  LATEST=$(curl -s "${RAPID_SYNC_URL}/commit" | jq -r '.result.signed_header.header.height')
  echo "LATEST=$LATEST"

  # Calculate the snapshot height
  let "SNAPSHOT_HEIGHT=$LATEST / 100 * 100"
  echo "SNAPSHOT_HEIGHT=$SNAPSHOT_HEIGHT"

  # Get the snapshot hash
  SNAPSHOT_HASH=$(curl -s $RAPID_SYNC_URL/commit\?height\=$SNAPSHOT_HEIGHT | jq -r '.result.signed_header.commit.block_id.hash')
  echo "SNAPSHOT_HASH=$SNAPSHOT_HASH"

  dasel put -f /halo/config/config.toml -v true statesync.enable
  dasel put -f /halo/config/config.toml -v "${RAPID_SYNC_URL},${RAPID_SYNC_URL}" statesync.rpc_servers
  dasel put -f /halo/config/config.toml -v $SNAPSHOT_HEIGHT statesync.trust_height
  dasel put -f /halo/config/config.toml -v $SNAPSHOT_HASH statesync.trust_hash
fi

# halovisor will create a subprocess to handle upgrades
# so we need a special way to handle SIGTERM

# Start the process in a new session, so it gets its own process group.
# Word splitting is desired for the command line parameters
# shellcheck disable=SC2086
setsid "$@" ${CL_EXTRAS} &
pid=$!

# Trap SIGTERM in the script and forward it to the process group
trap 'kill -TERM -$pid' TERM

# Wait for the background process to complete
wait $pid
