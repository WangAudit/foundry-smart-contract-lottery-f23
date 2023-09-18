# Proveably Random Raffle Contract

## About

This code is to proveably create a random smart contract lottery

## What we want it to do?

1. Users can enter by paying for a ticker
    1. The ticket fees are going to go to the winner during the draw
2. After X period of time, the lottery will automatically draw a winner
    1. And this will be done programatically
3. Using Chainlink VRF and Chainlink Automation
    1. Chainlink VRF -> Randomness
    2. Chainlink Autometion -> Time based trigger

## Tests

1. Write some deploy scripts
2. Write our tests
    1. Work on a local chain
    2. Forked Testnet
    3. Forked Mainnet
3. Test pushing to GitHub
    1. Initial Push
    2. Updating README