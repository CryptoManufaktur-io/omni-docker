# omni-docker

Docker compose for Omni

Meant to be used with central-proxy-docker for traefik and Prometheus remote write; use :ext-network.yml in COMPOSE_FILE inside .env in that case.

## Quick setup

Run `cp default.env .env`, then `nano .env`, and update values like MONIKER, NETWORK, HOST_IP and RAPID_SYNC_URL.

If you want the consensus node RPC ports exposed locally, use `rpc-shared.yml` in `COMPOSE_FILE` inside `.env`.

- `./omnid install` brings in docker-ce, if you don't have Docker installed already.
- `docker compose run --rm create-validator-keys` creates the consensus/validator node keys
- `docker compose run --rm import-validator-keys` imports the generated consensus/validator node key and state files into the docker volume
- `./omnid up`

To update the software, run `./omnid update` and then `./omnid up`

## Validator

### Key Generation

Run `docker compose run --rm create-validator-keys`

It is meant to be executed only once, it has no sanity checks and creates the `priv_validator_key.json`, `priv_validator_state.json` and `voter_state.json` files inside the `keys/consensus/` folder.

Remember to backup those files if you're running a validator.

You can also export the keys from the docker volume, into the `keys/consensus/` folder by running: `docker compose run --rm export-validator-keys`.

### Operator Wallet Creation

An operator wallet is needed for staking operations. We provide a simple command to generate it, so it can be done in an air-gapped environment. It is meant to be executed only once, it has no sanity checks. It creates the operator wallet and stores the result in the `keys/operator/` folder.

Make sure to backup the `keys/operator/operator-private-key-{ADDRESS}` file, it is the only way to recover the wallet.

Run `docker compose run --rm create-operator-wallet`

### Register Validator

This assumes an operator wallet `keys/operator/operator-private-key-{ADDRESS}` is present, and the `priv_validator_key.json` is present in the `keys/consensus/` folder.

```
docker compose run --rm halo-cli consensus-pubkey
Consensus public key: 039c302ca4a1b9316803884648f4f4bae81f3b39156fb51851d68e359303ca367e
```

```
docker compose run --rm omni-cli operator create-validator \
  --consensus-pubkey-hex=039c302ca4a1b9316803884648f4f4bae81f3b39156fb51851d68e359303ca367e \
  --network=omega \
  --private-key-file=./operator-private-key-0x7DA1b1213ACDf64034c5bd3b60281d2805cdA2a6 \
  --self-delegation 100
```

### CLI

You can use the `omni` and `halo` CLI from the containers:

- `docker compose run --rm halo-cli status --node http://halo:26657`
- `docker compose run --rm omni-cli --help`

## Version

Omni Docker uses a "semver-ish" scheme.

First digit, major shifts in how things work. The last one was Ethereum merge. I do not expect another shift that large.
Second through fourth digit, semver.

This is omni-docker v0.2
