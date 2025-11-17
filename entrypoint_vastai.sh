#!/bin/bash

#-------------------------------------------------------------------
# FRP
#-------------------------------------------------------------------
prepare_tunnel() {
    curl -L https://github.com/fatedier/frp/releases/download/v0.63.0/frp_0.63.0_linux_amd64.tar.gz | tar -xz --strip-components=1 -C /home/gensyn/frpc
    chmod +x /home/gensyn/frpc/frpc
    export LOCAL_IP="localhost"
    export LOCAL_PORT="3000"
    export PROXY_HASH=$(echo -n "${NODE_ID}${LOCAL_IP}${LOCAL_PORT}${NODE_PROXY_SALT}" | md5sum | cut -d ' ' -f1)
    export PROXY_URL="${PROXY_HASH}.${NODE_PROXY_URL}"
    # export NODE_PROXY_URL=${NODE_PROXY_URL}
    export NODE_PROXY_PORT=${NODE_PROXY_PORT:-7000}
}
write_frpc_link() {
    while true; do
        echo -n "https://${PROXY_URL}" > /home/gensyn/frpc/link
        sleep 5m
    done
}

start_tunnel() {
    while true; do
        /home/gensyn/frpc/frpc --config /home/gensyn/rl_swarm/frp/config.toml 2>&1 | tee -a /home/gensyn/frpc/log.log
    done
}

function run_node_manager() {
    MANIFEST_FILE=/home/gensyn/rl_swarm/node-manager/nodeV3.yaml \
    MODE=init \
    /home/gensyn/rl_swarm/node-manager/node-manager | tee /home/gensyn/rl_swarm/logs/node_manager.log

    while true; do
        MANIFEST_FILE=/home/gensyn/rl_swarm/node-manager/nodeV3.yaml \
        MODE=sidecar \
        /home/gensyn/rl_swarm/node-manager/node-manager | tee /home/gensyn/rl_swarm/logs/node_manager.log
    done
}
# function get_last_log {
#     echo "Starting..." > /home/gensyn/rl_swarm/logs/last_40.log
#     while true; do
#         sleep 5m
#         cat /home/gensyn/rl_swarm/logs/node_log.log | tail -40 > /home/gensyn/rl_swarm/logs/last_40.log
#     done
# }

mkdir -p /home/gensyn/rl_swarm/modal-login/temp-data
mkdir -p /home/gensyn/rl_swarm/keys
mkdir -p /home/gensyn/rl_swarm/configs
mkdir -p /home/gensyn/rl_swarm/logs
mkdir -p /home/gensyn/rl_swarm/out
mkdir -p /home/gensyn/frpc

volumes=(
    /home/gensyn/rl_swarm/modal-login/temp-data
    /home/gensyn/rl_swarm/keys
    /home/gensyn/rl_swarm/configs
    /home/gensyn/rl_swarm/logs
    /home/gensyn/rl_swarm/out
    /home/gensyn/frpc
)

for volume in ${volumes[@]}; do
    sudo chown -R 1001:1001 $volume
done

# get_last_log &
prepare_tunnel
write_frpc_link &
start_tunnel &
run_node_manager &
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

./run_rl_swarm.sh
