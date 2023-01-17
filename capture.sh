#!/bin/bash
# set -xeu

tmp_folder=/tmp/capture
mkdir -p "$tmp_folder"
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

if [ "${interface:-}" == "" ]; then
    echo "no interface is found through $DST"
    exit 1
fi
tcpdump_args=" -i $interface"

if [ "${DURATION:-}" != "" ]; then
    tcpdump_args="$tcpdump_args -G $DURATION -W 1"
fi
# tcpdump cannot be stopped when a determined size reaches.
# elif [ "$MAXCAPTURESIZE" != "" ]; then
#    tcpdump_args="$tcpdump_args -C $MAXCAPTURESIZE"
#fi

file_name="$tmp_folder/$CAPTURE_NAME-$(hostname)-$(date +%Y%m%d%H%M%S%Z)"
tcpdump_file_name="${file_name}.pcap"
tcpdump_args="$tcpdump_args -w $tcpdump_file_name"

echo "tcpdump arguments: $tcpdump_args"

sh -c "tcpdump $tcpdump_args"
INCLUDE_METADATA=$(echo "${INCLUDE_METADATA:-}" | tr '[:upper:]' '[:lower:]')
if [ "${INCLUDE_METADATA}" == "true" ]; then
    metadata_file_name="${file_name}.metadata.txt"
    echo "collect metadata"
    (
        ip route;
        ip nei;
        # more to add
        # better formatting
    )> "$metadata_file_name"
fi

mv $tmp_folder/* "$HOSTPATH"
