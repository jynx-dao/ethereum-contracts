# Ethereum Contracts

This repository contains Ethereum smart contracts, which are used to bridge assets to the Jynx network and to distribute JYNX tokens.

## Installation

These contracts have been developed using [Truffle](https://trufflesuite.com). To install them you should checkout the code and run the commands below:

* `npm install`
* `truffle compile`

## Testing

The unit tests require Ganache to be running with a specific mnemonic (see [scripts/ganache.sh](https://github.com/jynx-pro/ethereum-contracts/blob/main/scripts/ganache.sh)). For convenience, you can run the tests with the command below:

* `npm run test`

Generate a code coverage report by executing the command below:

* `truffle run coverage`

The HTML report will be available at `coverage/index.html`

## License
[MIT](https://choosealicense.com/licenses/mit)
