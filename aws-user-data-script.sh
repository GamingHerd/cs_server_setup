#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

STEAM_USER="steam"
AWS_REGION="us-east-1"
CS2_DIR="/home/steam/cs2"
CSGO_GAME_DIR="$CS2_DIR/game/csgo"
SDK64_DIR="/home/steam/.steam/sdk64/"
GITHUB_MATCHZY_SERVER_CONFIG_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/matchzy-config.cfg"
STEAMCMD_UPDATE_SCRIPT_FILENAME="cs2-steamcmd-update-script.sh"
GITHUB_CS2_STEAMCMD_UPDATE_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/$STEAMCMD_UPDATE_SCRIPT_FILENAME"
FULL_PACKAGE_UPDATE_SCRIPT_FILENAME="cs2-full-package-update-script.sh"
GITHUB_CS2_FULL_PACKAGE_UPDATE_SCRIPT_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/$FULL_PACKAGE_UPDATE_SCRIPT_FILENAME"
UPDATE_SHELL_FILES_FILENAME="cs2-update-shell-files-script.sh"
GITHUB_UPDATE_SHELL_FILES_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/$UPDATE_SHELL_FILES_FILENAME"
ENSURE_RUNNING_SCRIPT_FILENAME="cs2-ensure-running-script.sh"
GITHUB_ENSURE_RUNNING_SCRIPT_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/$ENSURE_RUNNING_SCRIPT_FILENAME"
MATCHZY_DIR="$CSGO_GAME_DIR/cfg/MatchZy"
MATCHZY_ADMINS_FILE_PATH="$MATCHZY_DIR/admins.json"
MATCHZY_WHITELIST_FILE_PATH="$MATCHZY_DIR/whitelist.cfg"
MATCHZY_CONFIG_FILE_PATH="$MATCHZY_DIR/config.cfg"
MATCHZY_KNIFE_CONFIG_FILE_PATH="$MATCHZY_DIR/knife.cfg"
MATCH_TEMP_SERVER_FILE_PATH="/tmp/matchzy-server.cfg"
EAGLE_STEAM_ID="76561197972259038"
GAMEINFO_FILE_PATH="$CSGO_GAME_DIR/gameinfo.gi"
MATCHZY_VERSION="0.8.6"
METAMOD_FILE_NAME="mmsource-2.0.0-git1314-linux.tar.gz"
METAMOD_URL_PATH_VERSION="2.0"
COUNTER_STRIKE_SHARP_FILE_NAME="counterstrikesharp-with-runtime-build-277-linux-cdb7a6e.zip"
COUNTER_STRIKE_SHARP_FILE_URL="v277/$COUNTER_STRIKE_SHARP_FILE_NAME"

# Accept the SteamCMD license agreement automatically
echo steam steam/question select "I AGREE" | sudo debconf-set-selections && echo steam steam/license note '' | sudo debconf-set-selections

sudo add-apt-repository -y multiverse
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt update
sudo apt-get install -y unzip
sudo apt-get install -y jq
sudo apt install -y lib32z1 lib32gcc-s1 lib32stdc++6 steamcmd
sudo snap install aws-cli --classic
sudo snap start amazon-ssm-agent

STEAM_USER_PW_JSON=$(aws secretsmanager get-secret-value --secret-id 'ec2-steam-user-pw' --region $AWS_REGION --query 'SecretString' --output text)
STEAM_USER_PW=$(echo "$STEAM_USER_PW_JSON" | jq -r '."ec2-user-steam-pw"')
STEAM_GAME_SERVER_TOKEN_JSON=$(aws secretsmanager get-secret-value --secret-id 'steam-game-server-token' --region $AWS_REGION --query 'SecretString' --output text)
STEAM_GAME_SERVER_TOKEN=$(echo "$STEAM_GAME_SERVER_TOKEN_JSON" | jq -r '."steam-game-server-token"')
RCON_PASSWORD_JSON=$(aws secretsmanager get-secret-value --secret-id 'rcon-password' --region $AWS_REGION --query 'SecretString' --output text)
RCON_PASSWORD=$(echo "$RCON_PASSWORD_JSON" | jq -r '."rcon-password"')

# Check if the user already exists
if id "$STEAM_USER" &>/dev/null; then
  echo "User $STEAM_USER already exists."
else
  # Create a user account named steam to run SteamCMD safely, isolating it from the rest of the operating system.
  # As the root user, create the steam user:
  sudo useradd -m "$STEAM_USER"
  echo "User $STEAM_USER created."
  echo "steam:$STEAM_USER_PW" | sudo chpasswd
  # Add the 'steam' user to the 'sudo' group to grant sudo privileges
  sudo usermod -aG sudo steam
  # Configure 'steam' to use sudo without a password
  echo "steam ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/steam
fi

sudo -i -u steam bash <<EOF
  # Check if the cs2 directory exists
  if [ ! -d "$CS2_DIR" ]; then
    # Directory does not exist, so create it
    mkdir -p "$CS2_DIR"
    echo "Directory $CS2_DIR created."
  else
    echo "Directory $CS2_DIR already exists."
  fi

  if [ ! -d "$SDK64_DIR" ]; then
    # Directory does not exist, so create it
    mkdir -p "$SDK64_DIR"
    echo "Directory $SDK64_DIR created."
  else
    echo "Directory $SDK64_DIR already exists."
  fi

  # Run SteamCMD
  /usr/games/steamcmd +force_install_dir /home/steam/cs2 +login anonymous +app_update 730 validate +quit

  cd /home/steam

  wget -O "$STEAMCMD_UPDATE_SCRIPT_FILENAME" "$GITHUB_CS2_STEAMCMD_UPDATE_URL"
  chmod +x "$STEAMCMD_UPDATE_SCRIPT_FILENAME"

  wget -O "$FULL_PACKAGE_UPDATE_SCRIPT_FILENAME" "$GITHUB_CS2_FULL_PACKAGE_UPDATE_SCRIPT_URL"
  chmod +x "$FULL_PACKAGE_UPDATE_SCRIPT_FILENAME"

  wget -O "$UPDATE_SHELL_FILES_FILENAME" "$GITHUB_UPDATE_SHELL_FILES_URL"
  chmod +x "$UPDATE_SHELL_FILES_FILENAME"

  wget -O "$ENSURE_RUNNING_SCRIPT_FILENAME" "$GITHUB_ENSURE_RUNNING_SCRIPT_URL"
  chmod +x "$ENSURE_RUNNING_SCRIPT_FILENAME"

  cd "$CS2_DIR"

  # Download the latest MetaMod build
  wget "https://mms.alliedmods.net/mmsdrop/$METAMOD_URL_PATH_VERSION/$METAMOD_FILE_NAME"

  # Extract MetaMod to the CS2 directory
  tar -xzvf "$METAMOD_FILE_NAME" -C "$CSGO_GAME_DIR"

  # Remove the downloaded MetaMod tar.gz file
  rm "$METAMOD_FILE_NAME"

  METAMOD_GAMEINFO_ENTRY="                        Game    csgo/addons/metamod"

  if grep -Fxq "$METAMOD_GAMEINFO_ENTRY" "$GAMEINFO_FILE_PATH"; then
    echo "The entry '$METAMOD_GAMEINFO_ENTRY' already exists in ${GAMEINFO_FILE_PATH}. No changes were made."
  else
    awk -v new_entry="$METAMOD_GAMEINFO_ENTRY" '
        BEGIN { found=0; }
        // {
            if (found) {
                print new_entry;
                found=0;
            }
            print;
        }
        /Game_LowViolence/ { found=1; }
    ' "$GAMEINFO_FILE_PATH" > "$GAMEINFO_FILE_PATH.tmp" && mv "$GAMEINFO_FILE_PATH.tmp" "$GAMEINFO_FILE_PATH"

    echo "The file ${GAMEINFO_FILE_PATH} has been modified successfully. '$METAMOD_GAMEINFO_ENTRY' has been added."
  fi

  # Download the latest CounterStrikeSharp build
  wget "https://github.com/roflmuffin/CounterStrikeSharp/releases/download/$COUNTER_STRIKE_SHARP_FILE_URL"

  # Extract CounterStrikeSharp to the CS2 directory
  unzip -o "$COUNTER_STRIKE_SHARP_FILE_NAME" -d "$CSGO_GAME_DIR"

  rm "$COUNTER_STRIKE_SHARP_FILE_NAME"

  # Download the latest MatchZy build
  wget "https://github.com/shobhit-pathak/MatchZy/releases/download/$MATCHZY_VERSION/MatchZy-$MATCHZY_VERSION.zip"

  # Extract MatchZy to the CS2 directory
  unzip -o "MatchZy-$MATCHZY_VERSION.zip" -d "$CSGO_GAME_DIR"

  # Remove the downloaded MatchZy .zip file
  rm "MatchZy-$MATCHZY_VERSION.zip"

  # Symlink the steamclient.so to expected path
  ln -sf /home/steam/.local/share/Steam/steamcmd/linux64/steamclient.so "$SDK64_DIR"

  # Replace MatchZy admins entry with proper admin
  sed -i "s/\"76561198154367261\": \".*\"/\"$EAGLE_STEAM_ID\": \"\"/" "$MATCHZY_ADMINS_FILE_PATH"

  # Cange the knife round time to 69 seconds (nice)
  sed -i "s/^mp_roundtime .*/mp_roundtime 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"
  sed -i "s/^mp_roundtime_defuse .*/mp_roundtime_defuse 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"
  sed -i "s/^mp_roundtime_hostage .*/mp_roundtime_hostage 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"

  # Only whitelist admin for now until a match would Start
  echo "$EAGLE_STEAM_ID" > "$MATCHZY_WHITELIST_FILE_PATH"

  # Replace MatchZy server config with custom config from GamingHerd GitHub
  wget -O "$MATCH_TEMP_SERVER_FILE_PATH" "$GITHUB_MATCHZY_SERVER_CONFIG_URL"
  mv "$MATCH_TEMP_SERVER_FILE_PATH" "$MATCHZY_CONFIG_FILE_PATH"

  # Overwrite the rcon password in the server.cfg file
  echo "rcon_password $RCON_PASSWORD" > "$CSGO_GAME_DIR/cfg/server.cfg"
  echo "tv_enable 1" >> "$CSGO_GAME_DIR/cfg/server.cfg"
  echo "tv_advertise_watchable 1" >> "$CSGO_GAME_DIR/cfg/server.cfg"

  # Start the CS2 server
  /home/steam/cs2/game/bin/linuxsteamrt64/cs2 -dedicated -console -usercon -nobots +map de_inferno +game_mode 1 +game_type 0 +sv_setsteamaccount "$STEAM_GAME_SERVER_TOKEN" -maxplayers 11
EOF
