#!/bin/bash

DOMAIN="domain.name"
EMAIL="me@domain.name"
NUM_CLIENTS=2 # guest and main


IPV4_INNER=10.66.60.1
IPV6_INNER=fd42:42:42:1::1


apt install openconnect ocserv -y


iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
iptables -A INPUT -p udp -m udp --dport 443 -j ACCEPT
ip6tables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
ip6tables -A INPUT -p udp -m udp --dport 443 -j ACCEPT

apt install iptables-persistent -y
systemctl enable netfilter-persistent
netfilter-persistent save

apt install certbot -y
certbot certonly --standalone --preferred-challenges http --agree-tos --email $EMAIL -d $DOMAIN

cat <<EOT > /etc/ocserv/ocserv.conf
auth = "plain[passwd=/etc/ocserv/ocpasswd]"

tcp-port = 443
udp-port = 443

run-as-user = nobody
run-as-group = daemon
socket-file = /run/ocserv.socket

server-cert = /etc/letsencrypt/live/$DOMAIN/fullchain.pem
server-key = /etc/letsencrypt/live/$DOMAIN/privkey.pem

max-clients=16
max-same-clients=4

try-mtu-discovery = true
server-stats-reset-time = 604800
keepalive = 300
dpd = 60
mobile-dpd = 300

switch-to-tcp-timeout = 25

compression = true
no-compress-limit = 256

idle-timeout=1200
mobile-idle-timeout=1800
isolate-workers = true
cert-user-oid = 0.9.2342.19200300.100.1.1
tls-priorities = "NORMAL:%SERVER_PRECEDENCE:%COMPAT:-RSA:-VERS-SSL3.0:-ARCFOUR-128"
auth-timeout = 240
idle-timeout = 1200
mobile-idle-timeout = 1800
min-reauth-time = 300
max-ban-score = 80
ban-reset-time = 300
cookie-timeout = 300
deny-roaming = false
rekey-time = 172800
rekey-method = ssl
use-occtl = true
pid-file = /run/ocserv.pid


device = vpns
predictable-ips = true
default-domain = $DOMAIN

ipv4-network = $IPV4_INNER/24
ipv6-network = $IPV6_INNER/64

tunnel-all-dns = true

dns = $IPV4_INNER
dns = $IPV6_INNER

ping-leases = false

#route = 10.0.0.0/8
#route = 172.16.0.0/12
#route = 192.168.0.0/16
route = default

cisco-client-compat = false
dtls-legacy = false
EOT

rm -rf /etc/ocserv/ocpasswd
echo "Now create accounts for $USERS users"
for (( c=1; c<=$NUM_CLIENTS; c++ ))
do
	echo "USER #"$c
        read -p "Username>> " USERNAME
	ocpasswd -c /etc/ocserv/ocpasswd $USERNAME
done

systemctl enable ocserv
systemctl stop ocserv
systemctl start ocserv
