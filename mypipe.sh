#!/bin/sh

usage(){
    echo "usage: $0 <bridge-name> <container-id> <IP/netmask>"
}

set -e

if [ "$#" -ne "3" ]; then
    usage
    exit 0
fi

set +e
ip link show $1 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo 'bridge "$1" is found'
else
    ip link add $1 type bridge
    ip link set $1 up
fi

eth_id=-1

while :
do
    eth_id=$((eth_id+1))
    ip link show h_veth$eth_id > /dev/null 2>&1
    if [ $? -eq 0 ]; then
	continue
    fi
    ip link show g_veth$eth_id > /dev/null 2>&1
    if [ $? -eq 0 ]; then
	continue
    fi
    break
done

ip link add h_veth$eth_id type veth peer name g_veth$eth_id
ip link set dev h_veth$eth_id master $1

set +e
container_ps=`docker inspect $2 --format '{{.State.Pid}}'`
mkdir -p /var/run/netns
ln -s /proc/$container_ps/ns/net /var/run/netns/docker_$container_ps 2>/dev/null

set -e
ip link set g_veth$eth_id netns docker_$container_ps
ip netns exec docker_$container_ps ip link set g_veth$eth_id up
ip netns exec docker_$container_ps ip addr add $3 dev g_veth$eth_id
