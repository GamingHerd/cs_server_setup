#!/bin/bash

SETUP_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/cs2-setup.sh"

wget -q -O /tmp/cs2-setup.sh "$SETUP_URL"

chmod +x cs2-setup.sh

./cs2-setup.sh

rm -f /tmp/cs2-setup.sh
