#!/bin/sh

VIP=$(cat /usr/local/etc/keepalived/ip.sh | tr -d '\n')

sed "s|VIP_PLACEHOLDER|$VIP|g" /usr/local/etc/keepalived/keepalived.conf.template > /usr/local/etc/keepalived/keepalived.conf

exec /container/tool/run

