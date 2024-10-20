#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Accept the SteamCMD license agreement automatically
echo steam steam/question select "I AGREE" | sudo debconf-set-selections
echo steam steam/license note '' | sudo debconf-set-selections

echo "Starting CS2 server setup script..."

# Install necessary dependencies
sudo dpkg --add-architecture i386
sudo apt update
yes | sudo apt install binutils bsdmainutils bzip2 libsdl2-2.0-0:i386 pigz steamcmd unzip jq netcat lib32gcc-s1 lib32stdc++6
sudo snap install aws-cli --classic
sudo snap start amazon-ssm-agent

echo "Finished installing dependencies."

# Define environment variables
AWS_REGION="us-east-1"
STEAM_USER="cs2server"
CS2_DIR="/home/$STEAM_USER/serverfiles"
CSGO_GAME_DIR="$CS2_DIR/game/csgo"
CS2_SERVER_CFG="$CSGO_GAME_DIR/cfg/cs2server.cfg"
LINUXGSM_COMMON_CFG="/home/$STEAM_USER/lgsm/config-lgsm/$STEAM_USER/common.cfg"
GITHUB_MATCHZY_SERVER_CONFIG_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/matchzy-config.cfg"
MATCHZY_TEMP_SERVER_FILE_PATH="/tmp/matchzy-server.cfg"
GITHUB_MATCHZY_LIVE_OVERRIDE_CONFIG_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/matchzy_live_override.cfg"
GSM_CS2_SERVER_OVERRIDE_CONFIG_URL="https://raw.githubusercontent.com/GamingHerd/cs_server_setup/main/cs2server.cfg"
GSM_CS2_SERVER_OVERRIDE_FILE_PATH="/tmp/cs2server.cfg"
MATCHZY_TEMP_LIVE_OVERRIDE_FILE_PATH="/tmp/live_override.cfg"
MATCHZY_DIR="$CSGO_GAME_DIR/cfg/MatchZy"
MATCHZY_ADMINS_FILE_PATH="$MATCHZY_DIR/admins.json"
MATCHZY_CONFIG_FILE_PATH="$MATCHZY_DIR/config.cfg"
MATCHZY_KNIFE_CONFIG_FILE_PATH="$MATCHZY_DIR/knife.cfg"
MATCHZY_URL="https://github.com/shobhit-pathak/MatchZy/releases/download/0.8.6/MatchZy-0.8.6.zip"
EAGLE_STEAM_ID="76561197972259038"
GAMEINFO_FILE_PATH="$CSGO_GAME_DIR/gameinfo.gi"
METAMOD_URL="https://mms.alliedmods.net/mmsdrop/2.0/mmsource-2.0.0-git1314-linux.tar.gz"
METAMOD_GAMEINFO_ENTRY="                        Game    csgo/addons/metamod"
COUNTER_STRIKE_SHARP_URL="https://github.com/roflmuffin/CounterStrikeSharp/releases/download/v281/counterstrikesharp-with-runtime-build-281-linux-71ae253.zip"

# Fetch secret values from AWS Secrets Manager
STEAM_USER_PW=$(aws secretsmanager get-secret-value --secret-id 'ec2-steam-user-pw' --region $AWS_REGION --query 'SecretString' --output text | jq -r '."ec2-user-steam-pw"')
RCON_PASSWORD=$(aws secretsmanager get-secret-value --secret-id 'rcon-password' --region $AWS_REGION --query 'SecretString' --output text | jq -r '."rcon-password"')
DISCORD_WEBHOOK=$(aws secretsmanager get-secret-value --secret-id 'discord-webhook' --region $AWS_REGION --query 'SecretString' --output text | jq -r '."discord-webhook"')

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

# Execute as $STEAM_USER
sudo -i -u $STEAM_USER env AWS_REGION="$AWS_REGION" \
  CS2_DIR="$CS2_DIR" \
  CSGO_GAME_DIR="$CSGO_GAME_DIR" \
  CS2_SERVER_CFG="$CS2_SERVER_CFG" \
  LINUXGSM_COMMON_CFG="$LINUXGSM_COMMON_CFG" \
  GITHUB_MATCHZY_SERVER_CONFIG_URL="$GITHUB_MATCHZY_SERVER_CONFIG_URL" \
  MATCHZY_TEMP_SERVER_FILE_PATH="$MATCHZY_TEMP_SERVER_FILE_PATH" \
  GITHUB_MATCHZY_LIVE_OVERRIDE_CONFIG_URL="$GITHUB_MATCHZY_LIVE_OVERRIDE_CONFIG_URL" \
  GSM_CS2_SERVER_OVERRIDE_CONFIG_URL="$GSM_CS2_SERVER_OVERRIDE_CONFIG_URL" \
  GSM_CS2_SERVER_OVERRIDE_FILE_PATH="$GSM_CS2_SERVER_OVERRIDE_FILE_PATH" \
  MATCHZY_TEMP_LIVE_OVERRIDE_FILE_PATH="$MATCHZY_TEMP_LIVE_OVERRIDE_FILE_PATH" \
  MATCHZY_DIR="$MATCHZY_DIR" \
  MATCHZY_ADMINS_FILE_PATH="$MATCHZY_ADMINS_FILE_PATH" \
  MATCHZY_CONFIG_FILE_PATH="$MATCHZY_CONFIG_FILE_PATH" \
  MATCHZY_KNIFE_CONFIG_FILE_PATH="$MATCHZY_KNIFE_CONFIG_FILE_PATH" \
  MATCHZY_URL="$MATCHZY_URL" \
  EAGLE_STEAM_ID="$EAGLE_STEAM_ID" \
  GAMEINFO_FILE_PATH="$GAMEINFO_FILE_PATH" \
  METAMOD_URL="$METAMOD_URL" \
  COUNTER_STRIKE_SHARP_URL="$COUNTER_STRIKE_SHARP_URL" \
  METAMOD_GAMEINFO_ENTRY="$METAMOD_GAMEINFO_ENTRY" \
  RCON_PASSWORD="$RCON_PASSWORD" \
  DISCORD_WEBHOOK="$DISCORD_WEBHOOK" bash <<'EOF'

cd $CS2_DIR

echo "I am acting as $(whoami)"

echo "Starting install of linuxgsm."
curl -Lo linuxgsm.sh https://linuxgsm.sh && chmod +x linuxgsm.sh && bash linuxgsm.sh cs2server
./cs2server auto-install
echo "Completed install of linuxgsm."

# Install Metamod
echo "Installing metamod."
wget -q -O /tmp/metamod.tar.gz "$METAMOD_URL"
tar -xzf /tmp/metamod.tar.gz -C "$CSGO_GAME_DIR"
rm -f /tmp/metamod.tar.gz
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
echo "Completed installing metamod."

# Install CounterStrikeSharp
echo "Installing CounterStrikeSharp."
wget -q -O /tmp/cssharp.zip "$COUNTER_STRIKE_SHARP_URL"
unzip -qo /tmp/cssharp.zip -d "$CSGO_GAME_DIR"
rm -f /tmp/cssharp.zip
echo "Completed installing CounterStrikeSharp."

# Install MatchZy
echo "Installing MatchZy."
wget -q -O /tmp/matchzy.zip "$MATCHZY_URL"
unzip -qo /tmp/matchzy.zip -d "$CSGO_GAME_DIR"
rm -f /tmp/matchzy.zip
echo "Completed installing MatchZy."

# Update MatchZy admins
sed -i "s/\"76561198154367261\": \".*\"/\"$EAGLE_STEAM_ID\": \"\"/" "$MATCHZY_ADMINS_FILE_PATH"

# Set knife round time to 69 seconds (1.15 minutes)
sed -i "s/^mp_roundtime .*/mp_roundtime 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"
sed -i "s/^mp_roundtime_defuse .*/mp_roundtime_defuse 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"
sed -i "s/^mp_roundtime_hostage .*/mp_roundtime_hostage 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"

# Replace MatchZy server config with custom GamingHerd config
wget -q -O "$MATCHZY_TEMP_SERVER_FILE_PATH" "$GITHUB_MATCHZY_SERVER_CONFIG_URL"
mv "$MATCHZY_TEMP_SERVER_FILE_PATH" "$MATCHZY_CONFIG_FILE_PATH"

# Add MatchZy live_override.cfg
wget -q -O "$MATCHZY_TEMP_LIVE_OVERRIDE_FILE_PATH" "$GITHUB_MATCHZY_LIVE_OVERRIDE_CONFIG_URL"
mv "$MATCHZY_TEMP_LIVE_OVERRIDE_FILE_PATH" "$MATCHZY_DIR"

# Replace cs2server.cfg with GamingHerd override
wget -q -O "$GSM_CS2_SERVER_OVERRIDE_FILE_PATH" "$GSM_CS2_SERVER_OVERRIDE_CONFIG_URL"
mv "$GSM_CS2_SERVER_OVERRIDE_FILE_PATH" "$CS2_SERVER_CFG"

sed -i "s/^rcon_password\b.*/rcon_password \"$RCON_PASSWORD\"/" "$CS2_SERVER_CFG"

# Set up cron jobs
CRON_JOBS="*/5 * * * * /home/cs2server/cs2server monitor > /dev/null 2>&1
*/30 * * * * /home/cs2server/cs2server update > /dev/null 2>&1
0 0 * * 0 /home/cs2server/cs2server update-lgsm > /dev/null 2>&1"

crontab -l 2>/dev/null > /tmp/current_cronjobs
echo "$CRON_JOBS" >> /tmp/current_cronjobs
crontab /tmp/current_cronjobs
rm /tmp/current_cronjobs
echo "Cron jobs installed."

# Add Discord alerts to LinuxGSM
{
  echo ""
  echo "discordalert=\"on\""
  echo "discordwebhook=\"$DISCORD_WEBHOOK\""
  echo 'startparameters="-dedicated -usercon -ip 0.0.0.0 -port 27015 -maxplayers 12 +game_type 0 +game_mode 1 +exec cs2server.cfg"'
} | sudo tee -a "$LINUXGSM_COMMON_CFG"

EOF
