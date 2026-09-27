# Сеть и подсеть

export PREFIX=akimov-04
export ZONE=ru-central1-a
export CIDR=10.14.1.0/24
export DISK_SIZE=15

yc vpc network create --name "$PREFIX-net"

yc vpc subnet create \
    --name "$PREFIX-subnet" \
    --network-name "$PREFIX-net" \
    --zone "$ZONE" \
    --range "$CIDR"

yc vpc subnet list



# Машина в своей сети

yc compute instance create \
    --name "$PREFIX-app-1" \
    --zone "$ZONE" \
    --platform standard-v3 \
    --cores=2 \
    --core-fraction=20 \
    --memory=2 \
    --preemptible \
    --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,type=network-hdd,size="$DISK_SIZE" \
    --network-interface subnet-name="$PREFIX-subnet",nat-ip-version=ipv4 \
    --ssh-key ~/.ssh/id_ed25519.pub \
    --labels created-by=cli

yc compute instance create \
    --name "$PREFIX-app-2" \
    --zone "$ZONE" \
    --platform standard-v3 \
    --cores=2 \
    --core-fraction=20 \
    --memory=2 \
    --preemptible \
    --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,type=network-hdd,size="$DISK_SIZE" \
    --network-interface subnet-name="$PREFIX-subnet",nat-ip-version=ipv4 \
    --ssh-key ~/.ssh/id_ed25519.pub \
    --labels created-by=cli

