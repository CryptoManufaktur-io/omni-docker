# omni-docker

Docker compose for Omni

Meant to be used with central-proxy-docker for traefik and Prometheus remote write; use :ext-network.yml in COMPOSE_FILE inside .env in that case.

## Initial setup

The `./omnid` script can be used as a quick-start:

`./omnid install` brings in docker-ce, if you don't have Docker installed already.

`cp default.env .env`

Then `nano .env` and set the `MONIKER` and `HOST_IP`, and adjust `HALO_DOCKER_TAG`, `GETH_DOCKER_TAG`, `NETWORK` and `RAPID_SYNC_URL` if desired.

### Key Generation

Run `docker compose run --rm create-validator-keys`

It is meant to be executed only once, it has no sanity checks and creates the `priv_validator_key.json`, `priv_validator_state.json` and `voter_state.json` files inside the `config/` folder.

Remember to backup those files if you're running a validator.

### Start the node.

`./omnid up`

To update the software, run `./omnid update` and then `./omnid up`

## Version

Omni Docker uses a "semver-ish" scheme.

First digit, major shifts in how things work. The last one was Ethereum merge. I do not expect another shift that large.
Second through fourth digit, semver.

This is omni-docker v0.1
