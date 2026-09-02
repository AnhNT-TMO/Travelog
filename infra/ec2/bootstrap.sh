#!/bin/bash
# Chuẩn bị một EC2 t4g.small trắng (Ubuntu 24.04 arm64) để Kamal deploy vào.
# Chạy MỘT LẦN, bằng sudo, ngay sau khi tạo instance:
#
#   scp infra/ec2/bootstrap.sh ubuntu@<EIP>:/tmp/
#   ssh ubuntu@<EIP> 'sudo bash /tmp/bootstrap.sh'
#
# Idempotent — chạy lại không phá gì, dùng được sau khi thay instance.
#
# Kamal tự cài Docker nếu thiếu (`kamal server bootstrap`), nhưng nó KHÔNG làm
# ba việc quyết định box 2 GB này sống hay chết:
#   - swap: lúc deploy, container cũ và mới chạy song song ~30s, đỉnh RAM
#     vọt lên ~1.7 GB. Không swap thì kernel OOM-kill Postgres đúng lúc
#     container mới đang chạy db:prepare.
#   - giới hạn log Docker: mặc định json-file không có max-size, log đầy 30 GB
#     đĩa là app chết mà không hiểu vì sao.
#   - dọn image cũ: mỗi lần deploy để lại một image ~600 MB.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Phải chạy bằng sudo." >&2
  exit 1
fi

SWAP_FILE=/swapfile
SWAP_SIZE_MB=2048
DATA_DIR=/var/lib/travelog/postgres
BACKUP_DIR=/var/lib/travelog/backups
DEPLOY_USER=ubuntu

echo "==> 1/6 swap ${SWAP_SIZE_MB}MB"
if ! swapon --show=NAME --noheadings | grep -qx "$SWAP_FILE"; then
  if [[ ! -f $SWAP_FILE ]]; then
    # fallocate nhanh hơn dd nhiều và ext4 chấp nhận file swap fallocate.
    fallocate -l "${SWAP_SIZE_MB}M" "$SWAP_FILE"
    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE"
  fi
  swapon "$SWAP_FILE"
fi
grep -qx "${SWAP_FILE} none swap sw 0 0" /etc/fstab \
  || echo "${SWAP_FILE} none swap sw 0 0" >>/etc/fstab

echo "==> 2/6 sysctl"
# swappiness=10: chỉ swap khi thật cần. Swap ở đây là lưới an toàn cho đỉnh
# RAM lúc deploy, không phải chỗ để Postgres nằm thường trú — gp3 chậm hơn
# RAM vài trăm lần và đọc/ghi swap còn ăn IOPS của chính database.
cat >/etc/sysctl.d/99-travelog.conf <<'SYSCTL'
vm.swappiness = 10
vm.vfs_cache_pressure = 50
# Chỉ có một app trên máy nên để nó dùng hết RAM còn lại thay vì
# giữ dự phòng cho ai khác.
vm.overcommit_memory = 0
SYSCTL
sysctl --quiet --system

echo "==> 3/6 Docker"
if ! command -v docker >/dev/null 2>&1; then
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
usermod -aG docker "$DEPLOY_USER"

echo "==> 4/6 daemon.json"
# Giới hạn mặc định cho container KHÔNG tự khai log-opt — tức kamal-proxy và
# accessory postgres. Container app có khai riêng trong config/deploy.yml và
# giá trị ở đó thắng file này.
# live-restore: container sống qua lần restart dockerd (ví dụ khi apt nâng cấp).
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
# Bind mount của accessory db (config/deploy.yml). Entrypoint của image
# postgres tự chown sang uid của nó, không cần chown ở đây.
install -d -m 0700 "$DATA_DIR"
install -d -m 0750 "$BACKUP_DIR"

echo "==> 6/6 dọn image cũ hằng tuần"
# Kamal giữ lại image của các bản deploy trước (retain_containers: 2).
# Không dọn thì đĩa 30 GB đầy sau vài chục lần deploy.
cat >/etc/cron.weekly/travelog-docker-prune <<'CRON'
#!/bin/sh
# Chỉ xoá image không container nào dùng. --volumes KHÔNG được bật:
# nó sẽ xoá dữ liệu Postgres nếu sau này chuyển sang named volume.
/usr/bin/docker image prune --all --force --filter "until=168h" >/dev/null 2>&1
/usr/bin/docker builder prune --force >/dev/null 2>&1
CRON
chmod +x /etc/cron.weekly/travelog-docker-prune

echo
echo "Xong. Kiểm tra:"
free -h
echo
docker --version
echo
echo "Bước tiếp: từ máy Mac chạy 'kamal setup' (xem infra/ec2/README.md)."
