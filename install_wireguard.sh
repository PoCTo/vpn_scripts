#!/bin/bash
DOMAIN="domain.name"
INTERFACE="ens3"

IPV4_INNER=10.66.66.1
IPV6_INNER=fd42:42:42::1
PORT=51820
NUM_CLIENTS=4
DNS="$IPV4_INNER,$IPV6_INNER"

apt install -y wireguard wireguard-tools curl qrencode zip net-tools mailutils python3-pip wbritish wamerican

#ufw deny 80/any
#ufw deny 53/any
#ufw allow 22/any
#ufw allow 443/any
#ufw allow $PORT/any
#ufw allow from $IPV4_INNER/24
#ufw allow from $IPV6_INNER/64
#ufw enable
#systemctl restart ufw

#curl -sSL https://install.pi-hole.net | bash

#systemctl stop systemd-resolved
#systemctl disable systemd-resolved



SERVER_PRIVATE_KEY=`wg genkey`
SERVER_PUBLIC_KEY=`echo $SERVER_PRIVATE_KEY | wg pubkey`
echo $SERVER_PRIVATE_KEY
echo $SERVER_PUBLIC_KEY

if [ `systemctl is-active wg-quick@wg0` == "active" ]; then 
	systemctl stop wg-quick@wg0
fi

cat <<EOT > /etc/wireguard/wg0.conf
[Interface]
Address = $IPV4_INNER/24,$IPV6_INNER/64
ListenPort = $PORT
PrivateKey = $SERVER_PRIVATE_KEY

PostUp = iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE; ip6tables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE; ip6tables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE

EOT

mkdir -p /etc/wireguard/clients
rm -rf /etc/wireguard/clients/*

for (( c=2; c<=$NUM_CLIENTS+1; c++ ))
do
	CLIENT_NAME=`misc/random_words.py`
	CLIENT_NAME="$DOMAIN"_"$CLIENT_NAME"
        CLIENT_PRIVATE_KEY=`wg genkey`
	CLIENT_PUBLIC_KEY=`echo $CLIENT_PRIVATE_KEY | wg pubkey`
	echo $CLIENT_NAME
	CLIENT_IPV4=${IPV4_INNER::-1}$c
	CLIENT_IPV6=${IPV6_INNER::-1}$c
	echo $CLIENT_IPV4

	cat <<EOT >> /etc/wireguard/wg0.conf
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_IPV4/32,$CLIENT_IPV6/128
EOT

	cat <<EOT > /etc/wireguard/clients/$CLIENT_NAME.conf
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IPV4/32,$CLIENT_IPV6/128
DNS = $IPV4_INNER,$IPV6_INNER

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0,::/0
Endpoint = $DOMAIN:$PORT
EOT

qrencode -o /etc/wireguard/clients/$CLIENT_NAME.png  < /etc/wireguard/clients/$CLIENT_NAME.conf
qrencode -t ansiutf8 -r /etc/wireguard/clients/$CLIENT_NAME.png < /etc/wireguard/clients/$CLIENT_NAME.conf

done

echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/wg.conf
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.d/wg.conf
sysctl --system


systemctl start wg-quick@wg0
systemctl enable wg-quick@wg0

rm -rf ~/vpn_$DOMAIN.zip
zip -j ~/vpn_$DOMAIN.zip /etc/wireguard/clients/*

pip3 install telegram-send
telegram-send --configure
telegram-send --file ~/vpn_$DOMAIN.zip --caption "VPN for $DOMAIN"
