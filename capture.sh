#!/bin/bash
folder=/tmp/$(date +%s)
mkdir -p "$folder"
interface=""
if [ "$DST" == "NODE" ]; then
    # autodetect from default route, or
    # by configuration defined in configmap
    interface=$(ip route | awk '/default/ { print $5 }')
else
    ns_pids=$(lsns -t net |awk ' /net/ {print $4}' |grep -v "^1$")
    for ns_pid in $ns_pids; do
        ip_addr=$(nsenter -t "${ns_pid}" -n ip addr show eth0 | awk '/inet / {print $2}' | awk -F/ '{print $1}')
        if [ "$ip_addr" != "$DST" ]; then
            continue
        fi
        # get the 'id' of veth device in the container.
        veth_id=$(nsenter -t "${ns_pid}" -n ip link show eth0 |grep -oP '(?<=eth0@if)\d+(?=:)')

        # get the 'name' of veth device in the 'docker0' bridge (or other name),
        # which is the peer of veth device in the container.
        interface=$(ip link show |sed -nr "s/^${veth_id}: *([^ ]*)@if.*/\1/p")
        break
    done
fi

if [ "$interface" == "" ]; then
    echo "no interface is found through $DST"
    exit 1
fi
tcpdump_args=" -i $interface"

if [ $DURATION != "" ]; then
    tcpdump_args="$tcpdump_args -G $DURATION -W 1"
elif [ "$MAXCAPTURESIZE" != "" ]; then
    tcpdump_args="$tcpdump_args -C $MAXCAPTURESIZE"
fi

tcpdump $tcpdump_args -w $folder/capture.pcap

if [ $INCLUDE_METADATA == "" ]; then
    # collect metadata
    echo "xx"
fi

# zip the files collected