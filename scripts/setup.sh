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
SSID=""
read -p 'Please enter SSID to create [rpiwifi]: ' SSID
if [[ -n $SSID ]]; then
  sed -i "s/rpiwifi/$SSID/" /etc/hostapd/hostapd.conf
fi
WPAPASS=""
while [[ -z $WPAPASS ]]; do
  read -p 'Please enter a password to use for WPA security: ' WPAPASS
done
sed -i "s/ChangeMe/$WPAPASS/" /etc/hostapd/hostapd.conf

# Add a startup script
cp $(dirname $0)/init /etc/init.d/hostapd

# Set ip address immediately
ifconfig wlan0 192.168.42.1

# Setup AP based on http://elinux.org/RPI-Wireless-Hotspot
apt-get -y install udhcpd

cat << EOF > /etc/udhcpd.conf
start 192.168.42.2 # This is the range of IPs that the hostspot will give to client devices.
end 192.168.42.20
interface wlan0 # The device uDHCP listens on.
remaining yes
opt dns 8.8.8.8 4.2.2.2 # The DNS servers client devices will use.
opt subnet 255.255.255.0
opt router 192.168.42.1 # The Pi's IP address on wlan0 which we will set up shortly.
opt lease 864000 # 10 day DHCP lease time in seconds
EOF

sed -E -i "s/(.*DHCPD_ENABLED)/# \1/" /etc/default/udhcpd

sed -E -i "s/(.*allow-hotplug)/# \1/" /etc/network/interfaces
sed -E -i "s/(.*wpa-roam)/# \1/" /etc/network/interfaces
sed -E -i "s/(.*iface default)/# \1/" /etc/network/interfaces
sed -E -i "s/(.*iface wlan0)/# \1/" /etc/network/interfaces

cat << EOF >> /etc/network/interfaces
iface wlan0 inet static
  address 192.168.42.1
  netmask 255.255.255.0

up iptables-restore < /etc/iptables.ipv4.nat
EOF

echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd

echo 'net.ipv4.ip_forward=1' >>  /etc/sysctl.conf

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
iptables-save > /etc/iptables.ipv4.nat

# Start the hostapd service
service hostapd restart
service udhcpd restart

# Start services on boot
update-rc.d hostapd enable
update-rc.d udhcpd enable

