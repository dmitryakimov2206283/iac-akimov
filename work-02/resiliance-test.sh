LB_IP=$(yc load-balancer network-load-balancer get --name "$PREFIX-lb" \
  --format json | jq -r '.listeners[0].address')

APP_IP=$(yc compute instance get "$PREFIX-app-1" --format json \
  | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')

ping_lb () {
    for i in $(seq 1 5); do
        curl http://$LB_IP
    done
}

stop_nginx () {
    ssh student@$APP_IP "sudo systemctl stop nginx"
}

start_nginx () {
    ssh student@$APP_IP "sudo systemctl start nginx"
}

echo "--- До остановки nginx ---"
ping_lb

echo "--- После остановки nginx ---"
stop_nginx
ping_lb

echo "--- После возврата nginx ---"
start_nginx
ping_lb
