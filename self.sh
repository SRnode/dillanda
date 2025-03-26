#!/bin/bash

# Define color variables
GREEN="\e[1m\e[1;32m"
RED="\e[1m\e[1;31m"
BLUE='\033[0;34m'
NC="\e[0m"

# Print Logo and Welcome Message
echo -e "\033[0;32m"
echo "==============================="
echo "     COINSSPOR NODE CENTER     "
echo "==============================="
echo -e "\e[0m"
echo "Welcome to the COINSSPOR Node Setup!"
echo "This script will guide you through the node installation process."
read -p "Do you want to continue with the installation? (yes/no): " answer
if [ "$answer" != "yes" ]; then
    echo "Installation aborted."
    exit 1
fi

# Green text output function
printGreen() {
    echo -e "${GREEN}${1}${NC}"
}

# Updating packages and installing dependencies
printGreen "2. Updating packages..." && sleep 1
sudo apt update

printGreen "3. Installing dependencies..." && sleep 1
sudo apt install curl git wget htop tmux build-essential jq make lz4 gcc unzip -y

# Setting variables
echo "export WALLET=\"wallet\"" >> $HOME/.bash_profile
echo "export MONIKER=\"Saandy\"" >> $HOME/.bash_profile
echo "export EMPED_CHAIN_ID=\"selfchain-testnet\"" >> $HOME/.bash_profile
echo "export EMPED_PORT=\"17\"" >> $HOME/.bash_profile
echo "export BINARY_NAME=\"selfchaind\"" >> $HOME/.bash_profile
echo "export MINIMUM_GAS_PRICES=\"0.005uslf\"" >> $HOME/.bash_profile
echo "export KEYRING_BACKEND=\"test\"" >> $HOME/.bash_profile
source $HOME/.bash_profile

# Display user inputs
echo -e "Moniker:        \e[1m\e[32mSaandy\e[0m"
echo -e "Wallet:         \e[1m\e[32mwallet\e[0m"
echo -e "Chain id:       \e[1m\e[32mselfchain-testnet\e[0m"
echo -e "Node custom port:  \e[1m\e[32m17\e[0m"
echo -e "Binary name:    \e[1m\e[32mselfchaind\e[0m"
echo -e "Minimum gas prices: \e[1m\e[32m0.005uslf\e[0m"
echo -e "Keyring backend: \e[1m\e[32mtest\e[0m"

# Installing Go if needed
printGreen "1. Installing go..." && sleep 1
cd $HOME
GO_VERSION="1.22.3"
wget "https://golang.org/dl/go$GO_VERSION.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$GO_VERSION.linux-amd64.tar.gz"
rm "go$GO_VERSION.linux-amd64.tar.gz"
[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=\$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
source $HOME/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

echo $(go version) && sleep 1

# Installing binary from repository
printGreen "4. Installing binary..." && sleep 1
cd $HOME
wget https://snapshot.sychonix.com/testnet/selfchain/selfchain-snapshot.tar.lz4
tar -xvf $(basename https://snapshot.sychonix.com/testnet/selfchain/selfchain-snapshot.tar.lz4)
rm $(basename https://snapshot.sychonix.com/testnet/selfchain/selfchain-snapshot.tar.lz4)
chmod +x selfchaind
mv selfchaind ~/go/bin

# Configuring and initializing the app
printGreen "5. Configuring and initializing the app..." && sleep 1
selfchaind config node tcp://localhost:${EMPED_PORT}657
selfchaind config keyring-backend test
selfchaind config chain-id ${EMPED_CHAIN_ID}
selfchaind init ${MONIKER} --chain-id ${EMPED_CHAIN_ID}
sleep 1
echo done

# Downloading genesis and addrbook
printGreen "6. Downloading genesis and addrbook..." && sleep 1
wget -O $HOME/.selfchain/config/genesis.json https://snapshot.sychonix.com/testnet/selfchain/genesis.json
wget -O $HOME/.selfchain/config/addrbook.json https://snapshot.sychonix.com/testnet/selfchain/addrbook.json
sleep 1
echo done

# Adding seeds, peers, and configuring custom ports
printGreen "7. Adding seeds, peers, configuring custom ports, pruning, minimum gas price..." && sleep 1
SEEDS="7923e9a64c2b2986c54035aaace4db2dfc45ff21@rpc.selfchain-t.indonode.net:11456"
PEERS="54bc6768af48108d7c50344362165c7870d89275@37.27.52.25:13656"
sed -i -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*seeds *=.*/seeds = \"$SEEDS\"/}" \
       -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" \
       $HOME/.selfchain/config/config.toml

# Custom port configuration in app.toml
sed -i.bak -e "s%:1317%:${EMPED_PORT}317%g;
s%:8080%:${EMPED_PORT}080%g;
s%:9090%:${EMPED_PORT}090%g;
s%:9091%:${EMPED_PORT}091%g;
s%:8545%:${EMPED_PORT}545%g;
s%:8546%:${EMPED_PORT}546%g;
s%:6065%:${EMPED_PORT}065%g" $HOME/.selfchain/config/app.toml

# set custom ports in config.toml file
sed -i.bak -e "s%:26658%:${EMPED_PORT}658%g;
s%:26657%:${EMPED_PORT}657%g;
s%:6060%:${EMPED_PORT}060%g;
s%:26656%:${EMPED_PORT}656%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${EMPED_PORT}656\"%;
s%:26660%:${EMPED_PORT}660%g" $HOME/.selfchain/config/config.toml

# Pruning and gas price configuration
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.selfchain/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.selfchain/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"50\"/" $HOME/.selfchain/config/app.toml
sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0.005uslf"|g' $HOME/.selfchain/config/app.toml
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.selfchain/config/config.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.selfchain/config/config.toml
sleep 1
echo done

# Creating service file and starting the node
sudo tee /etc/systemd/system/selfchaind.service > /dev/null <<EOF
[Unit]
Description=selfchaind node
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/.selfchain
ExecStart=$(which selfchaind) start --home $HOME/.selfchain
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# Downloading snapshot and starting the node
printGreen "8. Downloading snapshot and starting node..." && sleep 1
selfchaind tendermint unsafe-reset-all --home $HOME/.selfchain
if curl -s --head curl https://server-5.coinsspor.com/testnet/empeiria/empeiria_2024-08-20_1043879_snap.tar.lz4 | head -n 1 | grep "200" > /dev/null; then
  curl https://server-5.coinsspor.com/testnet/empeiria/empeiria_2024-08-20_1043879_snap.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.selfchain
else
  echo "no snapshot found"
fi

# Enabling and starting the service
sudo systemctl daemon-reload
sudo systemctl enable selfchaind.service
sudo systemctl restart selfchaind.service && sudo journalctl -u selfchaind.service -f
