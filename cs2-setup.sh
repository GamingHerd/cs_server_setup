#!/bin/bash

AWS_REGION="us-east-1"
STEAM_USER="cs2server"
STEAM_USER_PW_JSON=$(aws secretsmanager get-secret-value --secret-id 'ec2-steam-user-pw' --region $AWS_REGION --query 'SecretString' --output text)
STEAM_USER_PW=$(echo "$STEAM_USER_PW_JSON" | jq -r '."ec2-user-steam-pw"')

# Check if the user already exists
if id "$STEAM_USER" &>/dev/null; then
  echo "User $STEAM_USER already exists."
else
  sudo useradd -m "$STEAM_USER"
  echo "User $STEAM_USER created."
  echo "$STEAM_USER:$STEAM_USER_PW" | sudo chpasswd
  sudo usermod -aG sudo "$STEAM_USER"
  echo "$STEAM_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$STEAM_USER
fi

sudo -u $STEAM_USER -s

STEAM_USER="cs2server"

cd /home/$STEAM_USER

AWS_REGION="us-east-1"
CS2_DIR="/home/cs2server/serverfiles"
CSGO_GAME_DIR="$CS2_DIR/game/csgo"
CS2_SERVER_CFG="$CSGO_GAME_DIR/cfg/cs2server.cfg"
LINUXGSM_COMMON_CFG="/home/cs2server/lgsm/config-lgsm/cs2server/common.cfg"
GITHUB_MATCHZY_SERVER_CONFIG_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/matchzy-config.cfg"
MATCH_TEMP_SERVER_FILE_PATH="/tmp/matchzy-server.cfg"
GITHUB_MATCHZY_LIVE_OVERRIDE_CONFIG_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/matchzy_live_override.cfg"
MATCHZY_TEMP_LIVE_OVERRIDE_FILE_PATH="/tmp/live_override.cfg"
MATCHZY_DIR="$CSGO_GAME_DIR/cfg/MatchZy"
MATCHZY_ADMINS_FILE_PATH="$MATCHZY_DIR/admins.json"
MATCHZY_CONFIG_FILE_PATH="$MATCHZY_DIR/config.cfg"
MATCHZY_KNIFE_CONFIG_FILE_PATH="$MATCHZY_DIR/knife.cfg"
MATCHZY_VERSION="0.8.6"
MATCHZY_URL="https://github.com/shobhit-pathak/MatchZy/releases/download/$MATCHZY_VERSION/MatchZy-$MATCHZY_VERSION.zip"
EAGLE_STEAM_ID="76561197972259038"
GAMEINFO_FILE_PATH="$CSGO_GAME_DIR/gameinfo.gi"
METAMOD_URL="https://mms.alliedmods.net/mmsdrop/2.0/mmsource-2.0.0-git1314-linux.tar.gz"
COUNTER_STRIKE_SHARP_URL="https://github.com/roflmuffin/CounterStrikeSharp/releases/download/v281/counterstrikesharp-with-runtime-build-281-linux-71ae253.zip"

sudo dpkg --add-architecture i386
sudo apt update
yes | sudo apt install binutils bsdmainutils bzip2 libsdl2-2.0-0:i386 pigz steamcmd unzip jq

curl -Lo linuxgsm.sh https://linuxgsm.sh && chmod +x linuxgsm.sh && bash linuxgsm.sh cs2server
yes | ./cs2server install

# Download the latest MetaMod build
wget -q -O /tmp/metamod.tar.gz "$METAMOD_URL"

# Extract MetaMod to the csgo directory
tar -xzf /tmp/metamod.tar.gz -C "$CSGO_GAME_DIR"

# Remove the downloaded MetaMod tar.gz file
rm -f /tmp/metamod.tar.gz

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
  ' "$GAMEINFO_FILE_PATH" >"$GAMEINFO_FILE_PATH.tmp" && mv "$GAMEINFO_FILE_PATH.tmp" "$GAMEINFO_FILE_PATH"

  echo "The file ${GAMEINFO_FILE_PATH} has been modified successfully. '$METAMOD_GAMEINFO_ENTRY' has been added."
fi

# Download the latest CounterStrikeSharp build
wget -q -O /tmp/cssharp.zip "$COUNTER_STRIKE_SHARP_URL"

# Extract CounterStrikeSharp to the CS2 directory
unzip -qo /tmp/cssharp.zip -d "$CSGO_GAME_DIR"

rm -f /tmp/cssharp.zip

# Download the latest MatchZy build
wget -q -O /tmp/matchzy.zip "$MATCHZY_URL"

# Extract MatchZy to the CS2 directory
unzip -qo /tmp/matchzy.zip -d "$CSGO_GAME_DIR"

# Remove the downloaded MatchZy .zip file
rm -f /tmp/matchzy.zip

# Replace MatchZy admins entry with proper admin
sed -i "s/\"76561198154367261\": \".*\"/\"$EAGLE_STEAM_ID\": \"\"/" "$MATCHZY_ADMINS_FILE_PATH"

# Cange the knife round time to 69 seconds (nice)
sed -i "s/^mp_roundtime .*/mp_roundtime 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"
sed -i "s/^mp_roundtime_defuse .*/mp_roundtime_defuse 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"
sed -i "s/^mp_roundtime_hostage .*/mp_roundtime_hostage 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"

# Replace MatchZy server config with custom config from GamingHerd GitHub
wget -q -O "$MATCH_TEMP_SERVER_FILE_PATH" "$GITHUB_MATCHZY_SERVER_CONFIG_URL"
mv "$MATCH_TEMP_SERVER_FILE_PATH" "$MATCHZY_CONFIG_FILE_PATH"

# Add MatchZy live_override.cfg
wget -q -O "$MATCHZY_TEMP_LIVE_OVERRIDE_FILE_PATH" "$GITHUB_MATCHZY_LIVE_OVERRIDE_CONFIG_URL"
mv "$MATCHZY_TEMP_LIVE_OVERRIDE_FILE_PATH" "$MATCHZY_DIR"

RCON_PASSWORD_JSON=$(aws secretsmanager get-secret-value --secret-id 'rcon-password' --region $AWS_REGION --query 'SecretString' --output text)
RCON_PASSWORD=$(echo "$RCON_PASSWORD_JSON" | jq -r '."rcon-password"')

# Replace existing configs
sed -i "s/^map\b.*/map \"de_inferno\"/" "$CS2_SERVER_CFG"
sed -i "s/^game_alias.*/game_alias \"competitive\"/" "$CS2_SERVER_CFG"

# New configs
echo "" | sudo tee -a "$CS2_SERVER_CFG"
echo "rcon_password $RCON_PASSWORD" | tee -a "$CS2_SERVER_CFG"
echo "tv_enable 1" | tee -a "$CS2_SERVER_CFG"
echo "tv_advertise_watchable 1" | tee -a "$CS2_SERVER_CFG"
echo "tv_delay 30" | tee -a "$CS2_SERVER_CFG"
echo "tv_name \"GamingHerdVision\"" | tee -a "$CS2_SERVER_CFG"

CRON_JOBS="*/5 * * * * /home/cs2server/cs2server monitor > /dev/null 2>&1
*/30 * * * * /home/cs2server/cs2server update > /dev/null 2>&1
0 0 * * 0 /home/cs2server/cs2server update-lgsm > /dev/null 2>&1"

# Add the cron jobs to the crontab for the cs2server user
(
  crontab -l -u $STEAM_USER 2>/dev/null
  echo "$CRON_JOBS"
) | crontab -u $STEAM_USER -

DISCORD_WEBHOOK_JSON=$(aws secretsmanager get-secret-value --secret-id 'discord-webhook' --region $AWS_REGION --query 'SecretString' --output text)
DISCORD_WEBHOOK=$(echo "$DISCORD_WEBHOOK_JSON" | jq -r '."discord-webhook"')

# Add Discord alerts
echo "" | sudo tee -a "$LINUXGSM_COMMON_CFG"
echo "discordalert=\"on\"" | tee -a "$LINUXGSM_COMMON_CFG"
echo "discordwebhook=\"$DISCORD_WEBHOOK\"" | tee -a "$LINUXGSM_COMMON_CFG"
