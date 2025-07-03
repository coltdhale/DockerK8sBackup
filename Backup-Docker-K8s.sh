#!/bin/bash
# Unified backup and restore script for Docker + MicroK8s
# Author: Colt Hale

set -e

BACKUP_ROOT=~/server-backups
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/backup-$DATE"
ARCHIVE_NAME="$BACKUP_ROOT/backup-$DATE.tar.gz"

DOCKER_IMG_DIR="$BACKUP_DIR/docker/images"
DOCKER_VOL_BACKUP="$BACKUP_DIR/docker/docker-volumes.tar.gz"

MICROK8S_RESOURCES="$BACKUP_DIR/microk8s/all-resources.yaml"
MICROK8S_SNAP_CURRENT="$BACKUP_DIR/microk8s/current-snap"
MICROK8S_SNAP_COMMON="$BACKUP_DIR/microk8s/common-snap"

RESTORE_DIR="$BACKUP_ROOT/restore-temp"

# ---------------- RESTORE ----------------
if [ "$1" == "--restore" ]; then
    echo "🧩 Starting restore from archive..."
    if [ -z "$2" ]; then
        echo "❌ Usage: ./backup_microk8s_docker.sh --restore <path/to/archive.tar.gz>"
        exit 1
    fi

    ARCHIVE_PATH="$2"
    echo "📦 Extracting $ARCHIVE_PATH to $RESTORE_DIR..."
    mkdir -p "$RESTORE_DIR"
    tar -xzf "$ARCHIVE_PATH" -C "$RESTORE_DIR"

    echo "▶️ Restoring Docker volumes..."
    sudo tar xzvf "$RESTORE_DIR"/backup-*/docker/docker-volumes.tar.gz -C /

    echo "▶️ Restoring Docker images..."
    for file in "$RESTORE_DIR"/backup-*/docker/images/*.tar.gz; do
        gunzip -c "$file" | docker load
    done

    echo "▶️ Restoring MicroK8s configuration..."
    sudo microk8s stop
    sudo rm -rf /var/snap/microk8s/current /var/snap/microk8s/common
    sudo cp -r "$RESTORE_DIR"/backup-*/microk8s/current-snap /var/snap/microk8s/current
    sudo cp -r "$RESTORE_DIR"/backup-*/microk8s/common-snap /var/snap/microk8s/common
    sudo microk8s start

    echo "▶️ Re-applying MicroK8s resources..."
    microk8s kubectl apply -f "$RESTORE_DIR"/backup-*/microk8s/all-resources.yaml

    echo "🧹 Cleaning up extracted files..."
    rm -rf "$RESTORE_DIR"

    echo "✅ Restore complete."
    exit 0
fi

# ---------------- BACKUP ----------------
echo "📦 Starting full backup..."
mkdir -p "$DOCKER_IMG_DIR" "$BACKUP_DIR/microk8s"

echo "▶️ Backing up Docker images..."
docker images --format '{{.Repository}}:{{.Tag}}' | while read -r image; do
    safe_name=$(echo "$image" | tr / _ | tr : _)
    docker save "$image" | gzip > "$DOCKER_IMG_DIR/${safe_name}.tar.gz"
done

echo "▶️ Backing up Docker volumes..."
sudo tar czvf "$DOCKER_VOL_BACKUP" /var/lib/docker/volumes

echo "▶️ Backing up MicroK8s resources..."
microk8s kubectl get all --all-namespaces -o yaml > "$MICROK8S_RESOURCES"

echo "▶️ Backing up MicroK8s config..."
sudo cp -r /var/snap/microk8s/current "$MICROK8S_SNAP_CURRENT"
sudo cp -r /var/snap/microk8s/common "$MICROK8S_SNAP_COMMON"

echo "📦 Archiving backup to $ARCHIVE_NAME..."
tar -czf "$ARCHIVE_NAME" -C "$BACKUP_ROOT" "$(basename "$BACKUP_DIR")"

echo "✅ Backup complete: $ARCHIVE_NAME"
echo "To restore: ./backup_microk8s_docker.sh --restore $ARCHIVE_NAME"
