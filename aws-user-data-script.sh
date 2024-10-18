#!/bin/bash

SETUP_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/cs2-setup.sh"
TEMP_FILE_PATH="/tmp/cs2-setup.sh"

wget -q -O "$TEMP_FILE_PATH" "$SETUP_URL"

chmod +x "$TEMP_FILE_PATH"

. "$TEMP_FILE_PATH"

rm -f "$TEMP_FILE_PATH"
