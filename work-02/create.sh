#!/usr/bin/env bash
set -euo pipefail

# ---- параметры варианта ----
PREFIX=akimov-04
ZONE_A=ru-central1-a
ZONE_B=ru-central1-b
CIDR_A=10.14.1.0/24
CIDR_B=10.14.2.0/24
APP_PORT=8012
GREETING=devlab
VM_COUNT=3
DISK_SIZE=20
BOOT_SIZE=15
IMAGE_FAMILY=ubuntu-2404-lts

while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefix)         PREFIX="$2";         shift 2 ;;
        --zone-a)         ZONE_A="$2";         shift 2 ;;
        --zone-b)         ZONE_B="$2";         shift 2 ;;
        --cidr-a)         CIDR_A="$2";         shift 2 ;;
        --cidr-b)         CIDR_B="$2";         shift 2 ;;
        --port)           APP_PORT="$2";       shift 2 ;;
        --greeting)       GREETING="$2";       shift 2 ;;
        --vm-count)       VM_COUNT="$2";       shift 2 ;;
        --disk-size)      DISK_SIZE="$2";      shift 2 ;;
        --boot-size)      BOOT_SIZE="$2";      shift 2 ;;
        --image-family)   IMAGE_FAMILY="$2";   shift 2 ;;
        *)
            echo "Ошибка: Неизвестный параметр $1" >&2
            exit 1
            ;;
    esac
done

echo "==> сеть и подсети"
yc vpc network create --name "$PREFIX-net"

yc vpc subnet create --name "$PREFIX-subnet-a" --network-name "$PREFIX-net" \
  --zone "$ZONE_A" --range "$CIDR_A"
yc vpc subnet create --name "$PREFIX-subnet-b" --network-name "$PREFIX-net" \
  --zone "$ZONE_B" --range "$CIDR_B"

echo "==> файл настройки из шаблона"
SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
export APP_PORT GREETING SSH_KEY
envsubst '${APP_PORT} ${GREETING} ${SSH_KEY}' \
  < work-02/cloud-init.tpl.yaml > work-02/cloud-init.yaml

echo "==> создаем дополнительный диск"
yc compute disk create --name "$PREFIX-data" --zone "$ZONE_A" \
  --size "$DISK_SIZE" --type network-hdd

echo "==> машины"
ZONES=("$ZONE_A" "$ZONE_B")
SUBNETS=("$PREFIX-subnet-a" "$PREFIX-subnet-b")

for i in $(seq 1 "$VM_COUNT"); do
  idx=$(( (i - 1) % 2 ))

  EXTRA_ARGS=()

  if [ "$i" -eq 1 ]; then
      EXTRA_ARGS+=( "--attach-disk" "disk-name=${PREFIX}-data,device-name=data" )
  fi

  yc compute instance create \
    --name "$PREFIX-app-$i" \
    --zone "${ZONES[$idx]}" \
    --platform standard-v3 \
    --cores=2 --core-fraction=20 --memory=2 \
    --preemptible \
    --create-boot-disk image-folder-id=standard-images,image-family="$IMAGE_FAMILY",type=network-hdd,size="$BOOT_SIZE" \
    "${EXTRA_ARGS[@]}" \
    --network-interface subnet-name="${SUBNETS[$idx]}",nat-ip-version=ipv4 \
    --hostname "$PREFIX-app-$i" \
    --metadata-from-file user-data=work-02/cloud-init.yaml
done

echo "==> целевая группа"

# собираем список машин: имя подсети и внутренний адрес каждой
TARGETS=""
for i in $(seq 1 "$VM_COUNT"); do
  idx=$(( (i - 1) % 2 ))
  IP=$(yc compute instance get "$PREFIX-app-$i" --format json \
    | jq -r '.network_interfaces[0].primary_v4_address.address')
  TARGETS="$TARGETS --target subnet-name=${SUBNETS[$idx]},address=$IP"
done

yc load-balancer target-group create --name "$PREFIX-tg" $TARGETS

echo "==> балансировщик"

# идентификатор целевой группы: балансировщик ссылается на неё по нему
TG_ID=$(yc load-balancer target-group get --name "$PREFIX-tg" --format json | jq -r .id)

yc load-balancer network-load-balancer create \
  --name "$PREFIX-lb" \
  --region-id ru-central1 \
  --listener name=http,port=80,target-port="$APP_PORT",external-ip-version=ipv4 \
  --target-group target-group-id="$TG_ID",healthcheck-name=http,healthcheck-interval=2s,healthcheck-timeout=1s,healthcheck-unhealthythreshold=2,healthcheck-healthythreshold=2,healthcheck-http-port="$APP_PORT",healthcheck-http-path=/


