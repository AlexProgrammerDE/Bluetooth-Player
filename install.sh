#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
else

export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
export UDEV=1

sudo systemctl stop bluetooth-player
sudo systemctl disable bluetooth-player
rm -r /etc/systemd/system/bluetooth-player.service

apt install -y alsa-base alsa-utils bluealsa bluez bluez-firmware python-gobject python-dbus mpg123

cp -r ./sounds/ /usr/src/sounds/

cp -r ./bluetooth-udev /usr/src/
chmod +x /usr/src/bluetooth-udev
cp -r ./udev-rules/ /etc/udev/rules.d/

cp -r ./bluetooth-agent /usr/src/
chmod +x /usr/src/bluetooth-agent

cp -r ./start.sh /usr/src/
chmod +x /usr/src/start.sh

if [[ -z "${BLUETOOTH_DEVICE_NAME+x}" ]]; then
read -r -p "With which name should the device be discoverable? [raspberrypi]:" BLUETOOTH_DEVICE_NAME
fi

if [[ -z "${BLUETOOTH_PIN_CODE+x}" ]]; then
read -r -p "Which Pin Code should be used? [0000]:" BLUETOOTH_PIN_CODE
fi

if [[ -z "${SYSTEM_OUTPUT_VOLUME+x}" ]]; then
read -r -p "Which output volume should be used? [100]:" SYSTEM_OUTPUT_VOLUME
fi

if [[ -z "${CONNECTION_NOTIFY_VOLUME+x}" ]]; then
read -r -p "Which connection notify output volume should be used? [75]:" CONNECTION_NOTIFY_VOLUME
fi

if [[ -z "$BLUETOOTH_DEVICE_NAME" ]]; then
BLUETOOTH_DEVICE_NAME=raspberrypi
fi

if [[ -z "$BLUETOOTH_PIN_CODE" ]]; then
BLUETOOTH_PIN_CODE=0000
fi

if [[ -z "$SYSTEM_OUTPUT_VOLUME" ]]; then
SYSTEM_OUTPUT_VOLUME=100
fi

if [[ -z "$CONNECTION_NOTIFY_VOLUME" ]]; then
CONNECTION_NOTIFY_VOLUME=75
fi

cat <<EOF >/usr/src/pre-start.sh
#!/bin/sh

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
else
export BLUETOOTH_DEVICE_NAME="$BLUETOOTH_DEVICE_NAME"
export BLUETOOTH_PIN_CODE="$BLUETOOTH_PIN_CODE"
export SYSTEM_OUTPUT_VOLUME="$SYSTEM_OUTPUT_VOLUME"
export CONNECTION_NOTIFY_VOLUME="$CONNECTION_NOTIFY_VOLUME"
source /usr/src/start.sh
fi
EOF
chmod +x /usr/src/pre-start.sh

sudo cp -r ./bluetooth-player.service /etc/systemd/system/

sudo systemctl enable bluetooth-player.service
sudo systemctl start bluetooth-player.service

fi
