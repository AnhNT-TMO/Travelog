#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Phải chạy bằng sudo." >&2
  exit 1
fi

SWAP_FILE=/swapfile
SWAP_SIZE_MB=2048
DATA_DIR=/var/lib/travelog/postgres
BACKUP_DIR=/var/lib/travelog/backups

if command -v dnf >/dev/null 2>&1; then
  PKG=dnf
  DEPLOY_USER="${DEPLOY_USER:-ec2-user}"
elif command -v apt-get >/dev/null 2>&1; then
  PKG=apt
  DEPLOY_USER="${DEPLOY_USER:-ubuntu}"
else
  echo "Không nhận ra distro (không có dnf lẫn apt-get)." >&2
  exit 1
fi
echo "Distro: $PKG, deploy user: $DEPLOY_USER"

echo "==> 1/6 swap ${SWAP_SIZE_MB}MB"
if ! swapon --show=NAME --noheadings | grep -qx "$SWAP_FILE"; then
  if [[ ! -f $SWAP_FILE ]]; then
    fallocate -l "${SWAP_SIZE_MB}M" "$SWAP_FILE"
    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE"
  fi
  swapon "$SWAP_FILE"
fi
grep -qx "${SWAP_FILE} none swap sw 0 0" /etc/fstab \
  || echo "${SWAP_FILE} none swap sw 0 0" >>/etc/fstab

echo "==> 2/6 sysctl"
cat >/etc/sysctl.d/99-travelog.conf <<'SYSCTL'
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.overcommit_memory = 0
SYSCTL
sysctl --quiet --system

echo "==> 3/6 Docker"
if ! command -v docker >/dev/null 2>&1; then
  if [[ $PKG == dnf ]]; then
    dnf install -y -q docker
    dnf install -y -q cronie || true
    systemctl enable --now crond 2>/dev/null || true
  else
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      >/etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io
  fi
fi
usermod -aG docker "$DEPLOY_USER"

echo "==> 4/6 daemon.json"
install -d -m 0755 /etc/docker
cat >/etc/docker/daemon.json <<'DAEMON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "3" },
  "live-restore": true
}
DAEMON
systemctl enable --now docker
systemctl reload docker 2>/dev/null || systemctl restart docker

echo "==> 5/6 thư mục dữ liệu"
install -d -m 0700 "$DATA_DIR"
install -d -m 0750 "$BACKUP_DIR"

echo "==> 6/6 dọn image cũ hằng tuần"
install -d -m 0755 /usr/local/bin
cat >/usr/local/bin/travelog-docker-prune <<'PRUNE'
/usr/bin/docker image prune --all --force --filter "until=168h" >/dev/null 2>&1
/usr/bin/docker builder prune --force >/dev/null 2>&1
PRUNE
chmod +x /usr/local/bin/travelog-docker-prune
echo '30 20 * * 0 root /usr/local/bin/travelog-docker-prune' >/etc/cron.d/travelog-docker-prune
chmod 0644 /etc/cron.d/travelog-docker-prune

echo
echo "Xong. Kiểm tra:"
free -h
echo
docker --version
echo
echo "Bước tiếp: từ máy Mac chạy 'kamal setup' (xem infra/ec2/README.md)."
