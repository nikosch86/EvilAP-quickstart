#!/bin/bash
WAN_INTERFACE=eth0
INTERFACE=wlan0
THREE_OCTETS="10.11.12"
NETWORK="24"
CIDR="${THREE_OCTETS}.0/${NETWORK}"
GATEWAY="${THREE_OCTETS}.1"
BROADCAST="${THREE_OCTETS}.255"

echo "preparing interface ${INTERFACE}"
iw dev ${INTERFACE} set power_save off
ip link set down dev ${INTERFACE}
ip addr flush ${INTERFACE}
ip link set up dev ${INTERFACE}
ip addr add ${GATEWAY}/${NETWORK} broadcast ${BROADCAST} dev ${INTERFACE}

echo "writing hostapd config"
sed "s/__WIFI_INTERFACE__/${INTERFACE}/g" hostapd.conf.template > hostapd.conf

echo "starting hostapd"
hostapd hostapd.conf &

echo "configuring routing and forwarding"
iptables -t nat -A POSTROUTING -o ${WAN_INTERFACE} -j MASQUERADE
iptables -A FORWARD -i ${INTERFACE} -o ${WAN_INTERFACE} -j ACCEPT
iptables -w -t nat -I PREROUTING -s ${CIDR} -d ${GATEWAY} -p tcp --dport 53 -j DNAT --to-destination ${GATEWAY}:53
iptables -w -t nat -I PREROUTING -s ${CIDR} -d ${GATEWAY} -p udp --dport 53 -j DNAT --to-destination ${GATEWAY}:53
sysctl net.ipv4.ip_forward=1

echo "writing dnsmasq config"
sed "s/__WIFI_INTERFACE__/${INTERFACE}/g; s/__THREE_OCTETS__/${THREE_OCTETS}/g; s/__GATEWAY__/${GATEWAY}/g" dnsmasq.conf.template > dnsmasq.conf

echo "starting dnsmasq"
dnsmasq -dC dnsmasq.conf &
