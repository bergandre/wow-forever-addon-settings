#!/usr/bin/env bash
# Share UI-addon SavedVariables across accounts: #2/#3 get symlinks to #1 (Karums-Warrior's account).
# Idempotent: re-run any time (e.g. if WoW replaced a link with a regular file).
set -euo pipefail

ACC_DIR="$(dirname "$(readlink -f "$0")")/WTF/Account"
MAIN="120675253#1"
OTHERS=("120675253#2" "120675253#3")
SHARED=(Titan TitanUI TitanGold Prat-3.0 TipTac Leatrix_Plus Bagnon Bagnonium Bagnon_BoE
        Bagnon_ItemInfo HealBot EnhanceQoL Scrap SpeedyAutoLoot Looti AutoLooter WhatsTraining SilverDragon RXPGuides)

if pgrep -fi 'wow\.exe' >/dev/null; then
  echo "WoW is running — close all clients first." >&2
  exit 1
fi

backup="$HOME/repositories/wow-ui-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$backup" -C "$ACC_DIR" "${OTHERS[@]/%//SavedVariables}"
echo "Backup: $backup"

for acc in "${OTHERS[@]}"; do
  sv="$ACC_DIR/$acc/SavedVariables"
  for name in "${SHARED[@]}"; do
    [[ -e "$ACC_DIR/$MAIN/SavedVariables/$name.lua" ]] || { echo "skip $name (missing in main)"; continue; }
    # Relative link so the repo works from any path (Wine follows it too).
    ln -sfn "../../$MAIN/SavedVariables/$name.lua" "$sv/$name.lua"
  done
  echo "linked $acc"
done
