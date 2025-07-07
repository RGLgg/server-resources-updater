#!/usr/bin/env bash
## TODO replace links with updater, color literals, steamworks inc dependencies

# Pulls latest updates for third party plugins, unzips the download into their respective folder, then deletes unnecessary files
wget -q -O tmp.zip https://github.com/ldesgoui/tf2-comp-fixes/releases/latest/download/tf2-comp-fixes.zip && unzip -o tmp.zip && rm tmp.zip && rm addons/sourcemod/updatefile.txt

