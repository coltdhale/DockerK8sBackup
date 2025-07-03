#!/bin/bash
# 🔐 Full Backup & Restore Script for Docker + MicroK8s (Ubuntu Server)
# Author: Colt Hale

set -euo pipefail

BACKUP_ROOT=~/server-backups
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/backup-$DATE"
ARCHIVE_NAME="$BACKUP_ROOT/backup-$DATE.tar.gz"
RESTORE_DIR="$BACKUP_ROOT/restore-temp"

DOCKER_IMG_DIR="$BACKUP_DIR/docker/images"
DOCKER_VOL_BACKUP="$BACKUP_DIR/docker/docker-volumes.tar.gz"

MICROK8S_RESOURCES="$BACKUP_DIR/microk8s/all-resources.yaml"
MICROK8S_SNAP_CURRENT="$BACKUP_DIR/microk8s/current-snap"
MICROK8S_SNAP_COMMON="$BACKUP_DIR/microk8s/common-snap"

# ---------------- RESTORE MODE ----------------
if [ "${1:-}" == "--restore" ]; then
    ARCHIVE_PATH="${2:-}"
    if [ -z "$ARCHIVE_PATH" ]; then
        echo -e "❌ Usage: \e[1m./backup_microk8s_docker.sh --restore <archive-path>\e[0m"
        exit 1
    fi

    echo -e "\n🔁 \e[1mRestoring from: $ARCHIVE_PATH\e[0m"
    mkdir -p "$RESTORE_DIR"
    tar -xzf "$ARCHIVE_PATH" -C "$RESTORE_DIR"

    echo -e "📦 Extracted to: $RESTORE_DIR"

    echo -e "🧰 \e[1mRestoring Docker Volumes...\e[0m"
    sudo tar xzvf "$RESTORE_DIR"/backup-*/docker/docker-volumes.tar.gz -C /

    echo -e "🐳 \e[1mRestoring Docker Images...\e[0m"
    for file in "$RESTORE_DIR"/backup-*/docker/images/*.tar.gz; do
        echo "🔄 Loading $(basename "$file")"
        gunzip -c "$file" | docker load
    done

    echo -e "⛔ \e[1mStopping MicroK8s before config restore...\e[0m"
    sudo microk8s stop

    echo -e "📁 \e[1mRestoring MicroK8s Config...\e[0m"
    sudo rm -rf /var/snap/microk8s/current /var/snap/microk8s/common
    sudo cp -r "$RESTORE_DIR"/backup-*/microk8s/current-snap /var/snap/microk8s/current
    sudo cp -r "$RESTORE_DIR"/backup-*/microk8s/common-snap /var/snap/microk8s/common

    echo -e "🚀 \e[1mStarting MicroK8s...\e[0m"
    sudo microk8s start
    sleep 5

    echo -e "📜 \e[1mReapplying MicroK8s Resources...\e[0m"
    microk8s kubectl apply -f "$RESTORE_DIR"/backup-*/microk8s/all-resources.yaml

    echo -e "🧹 \e[1mCleaning up restore temp files...\e[0m"
    rm -rf "$RESTORE_DIR"

    echo -e "\n✅ \e[1mRestore complete!\e[0m"
    exit 0
fi

# ---------------- BACKUP MODE ----------------

echo -e "\n📦 \e[1mStarting backup to: $BACKUP_DIR\e[0m"
mkdir -p "$DOCKER_IMG_DIR" "$BACKUP_DIR/microk8s"

# --- Docker Images ---
echo -e "\n🐳 \e[1mBacking up Docker images...\e[0m"
docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>' | while read -r image; do
    safe_name=$(echo "$image" | tr '/:' '__')
    echo "📤 Saving image: $image"
    docker save "$image" | gzip > "$DOCKER_IMG_DIR/${safe_name}.tar.gz"
done

# --- Docker Volumes ---
echo -e "\n💾 \e[1mBacking up Docker volumes...\e[0m"
sudo tar czvf "$DOCKER_VOL_BACKUP" /var/lib/docker/volumes

# --- MicroK8s Resources ---
echo -e "\n📜 \e[1mBacking up MicroK8s resources...\e[0m"
microk8s kubectl get all --all-namespaces -o yaml > "$MICROK8S_RESOURCES"

# --- MicroK8s Configs ---
echo -e "\n🧬 \e[1mBacking up MicroK8s configs (excluding runtime files)...\e[0m"
sudo rsync -a --exclude 'run/' /var/snap/microk8s/current "$MICROK8S_SNAP_CURRENT"
sudo rsync -a --exclude 'run/' /var/snap/microk8s/common "$MICROK8S_SNAP_COMMON"

# --- Archive Everything ---
echo -e "\n🗜️ \e[1mArchiving everything to: $ARCHIVE_NAME\e[0m"
sudo tar \
    --exclude='*/run/*' \
    --exclude='*.sock' \
    --exclude='*/io.containerd.*/*' \
    --exclude='*/snap/microk8s/common/run/*' \
    --exclude='*/plugins/*' \
    -czf "$ARCHIVE_NAME" -C "$BACKUP_ROOT" "$(basename "$BACKUP_DIR")"

echo -e "\n✅ \e[1mBackup complete!\e[0m"
echo -e "📦 Archive saved to: \e[1m$ARCHIVE_NAME\e[0m"
echo -e "\nTo restore: \e[1m./backup_microk8s_docker.sh --restore $ARCHIVE_NAME\e[0m"
