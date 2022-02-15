docker kill $(docker ps -q)
docker rm $(docker ps -a -q)
docker run --detach --publish 8545:8545 trufflesuite/ganache-cli:latest --mnemonic "wine nuclear screen canoe torch web charge sock embody party silver clock"
