#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
export UDEV=1

if [[ -z "$1" ]]; then
  BLUETOOTH_DEVICE_NAME=$(printf "raspberrypi")
fi

# Set the system volume here
SYSTEM_OUTPUT_VOLUME="${3:-100}"
echo "$SYSTEM_OUTPUT_VOLUME" > /usr/src/system_output_volume
printf "Setting output volume to %s%%\n" "$SYSTEM_OUTPUT_VOLUME"
amixer sset PCM,0 "$SYSTEM_OUTPUT_VOLUME%" > /dev/null &

# Set the volume of the connection notification sounds here
CONNECTION_NOTIFY_VOLUME="${4:-75}"
echo "$CONNECTION_NOTIFY_VOLUME" > /usr/src/connection_notify_volume
printf "Connection notify volume is %s%%\n" "$CONNECTION_NOTIFY_VOLUME"

# Set the discoverable timeout here
dbus-send --system --dest=org.bluez --print-reply /org/bluez/hci0 org.freedesktop.DBus.Properties.Set string:'org.bluez.Adapter1' string:'DiscoverableTimeout' variant:uint32:0 > /dev/null

printf "Restarting bluetooth service\n"
service bluetooth restart > /dev/null
sleep 2

# Redirect stdout to null, because it prints the old BT device name, which
# can be confusing and it also hides those commands from the logs as well.
printf "discoverable on\npairable on\nexit\n" | bluetoothctl > /dev/null

# Start bluetooth and audio agent
/usr/src/bluetooth-agent &

sleep 2
rm -rf /var/run/bluealsa/
/usr/bin/bluealsa -i hci0 -p a2dp-sink &

hciconfig hci0 up
hciconfig hci0 name "$BLUETOOTH_DEVICE_NAME"
if [ -z "$BLUETOOTH_PIN_CODE" ]; then
  hciconfig hci0 sspmode 1  # Secure Simple Pairing
  printf "Starting bluetooth agent in Secure Simple Pairing Mode (SSPM) - No PIN CODE\n"
else
  hciconfig hci0 sspmode 0  # Legacy pairing (PIN CODE)
  printf "Starting bluetooth agent in Legacy Pairing Mode - PIN CODE is \"%s\"\n" "$BLUETOOTH_PIN_CODE"
fi

sleep 2
printf "Device is discoverable as \"%s\"\n" "$BLUETOOTH_DEVICE_NAME"
/usr/bin/bluealsa-aplay --pcm-buffer-time=1000000 00:00:00:00:00:00
