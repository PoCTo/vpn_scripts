#!/bin/bash

IPV4_SUBNET=10.66.66.0/16
IPV6_SUBNET=fd42:42:42::1/48

iptables -A INPUT -s $IPV4_SUBNET -p tcp -m tcp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -s $IPV4_SUBNET -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
ip6tables -A INPUT -s $IPV6_SUBNET -p tcp -m tcp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
ip6tables -A INPUT -s $IPV6_SUBNET -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT

apt install iptables-persistent -y
systemctl enable netfilter-persistent
netfilter-persistent save

apt install curl unbound unbound-host -y
curl -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache

cat <<EOT >/etc/unbound/unbound.conf
server:
    num-threads: 4
    verbosity: 1
    root-hints: /var/lib/unbound/root.hints
    auto-trust-anchor-file: /var/lib/unbound/root.key
    interface: 0.0.0.0
    interface: ::0
    max-udp-size: 3072
    access-control: 0.0.0.0/0                 refuse
    access-control: ::0                       refuse
    access-control: $IPV4_SUBNET               allow
    access-control: $IPV6_SUBNET          allow
    access-control: 127.0.0.1                 allow
    private-address: $IPV4_SUBNET
    private-address: $IPV6_SUBNET
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-referral-path: yes
    unwanted-reply-threshold: 10000000
    val-log-level: 1
    cache-min-ttl: 1800
    cache-max-ttl: 14400
    prefetch: yes
    qname-minimisation: yes
    prefetch-key: yes
EOT

chown -R unbound:unbound /var/lib/unbound

systemctl stop systemd-resolved
systemctl disable systemd-resolved

systemctl enable unbound-resolvconf
sleep 1
systemctl enable unbound
sleep 1
systemctl stop unbound-resolvconf
systemctl start unbound-resolvconf
sleep 1
systemctl stop unbound
systemctl start unbound

