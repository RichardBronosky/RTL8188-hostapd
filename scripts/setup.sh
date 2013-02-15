#!/usr/bin/env bash
# This process is based on http://www.jenssegers.be/blog/43/Realtek-RTL8188-based-access-point-on-Raspberry-Pi

## No bash script should be considered releasable until it has this! ##
# Exit on use of an uninitialized variable
set -o nounset
# Exit if any statement returns a non-true return value (non-zero).
set -o errexit

# Since we are building our own hostapd version, remove the original hostapd you might have installed
apt-get autoremove hostapd

# Now build hostapd
(
    cd $(dirname $0)/../hostapd
    make && make install
)

# Create the conf file from template
cp $(dirname $0)/hostapd.conf /etc/hostapd/hostapd.conf

# Update default SSID & password
unset REPLY
read -p 'Please enter SSID to create [rpiwifi]: '
if [[ -z $REPLY ]]; then
    sed -i "s/rpiwifi/$REPLY/" /etc/hostapd/hostapd.conf
fi
unset REPLY
while [[ -z $REPLY ]]; do
    read -p 'Please enter a password to use for WPA security: '
done
sed -i "s/ChangeMe/$REPLY/" /etc/hostapd/hostapd.conf

# Add a startup script
cp $(dirname $0)/init /etc/init.d/hostapd

# Start the hostapd service
service hostapd restart
