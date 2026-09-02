#!/bin/bash
# Dump Postgres của accessory `db` ra file, giữ 7 bản, tuỳ chọn đẩy lên S3.
# Chạy TRÊN EC2 (script gọi docker exec vào container travelog-db).
#
# Cài chạy hằng ngày 2h sáng giờ VN (19:00 UTC hôm trước):
#   sudo install -m 0755 /tmp/pg_backup.sh /usr/local/bin/travelog-pg-backup
#   echo '0 19 * * * root /usr/local/bin/travelog-pg-backup' | sudo tee /etc/cron.d/travelog-backup
#
# Đây là lý do chạy Postgres trên cùng box thay vì RDS: không có snapshot tự
# động, không có point-in-time recovery. Mất box là mất tới bản dump gần nhất.
# Nếu chỗ dữ liệu đó đáng hơn ~12 USD/tháng thì dùng db.t4g.micro RDS.
set -euo pipefail

CONTAINER=travelog-db
DB=location_project_production
DB_USER=location_project
DEST=/var/lib/travelog/backups
KEEP_DAYS=7

# Tuỳ chọn: đẩy lên S3. Tạo /etc/travelog-backup.env với
#   BACKUP_S3_URI=s3://ten-bucket/travelog/postgres
#   AWS_ACCESS_KEY_ID=...
#   AWS_SECRET_ACCESS_KEY=...
#   AWS_DEFAULT_REGION=ap-southeast-1
# Không có file đó thì chỉ backup nội bộ (vẫn mất nếu mất EBS — đặt lịch
# EBS snapshot bằng Data Lifecycle Manager nếu không dùng S3).
ENV_FILE=/etc/travelog-backup.env
[[ -f $ENV_FILE ]] && set -a && . "$ENV_FILE" && set +a

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
file="${DEST}/${DB}-${stamp}.dump"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "pg_backup: container $CONTAINER không chạy" >&2
  exit 1
fi

mkdir -p "$DEST"

# -Fc = custom format: đã nén sẵn, restore chọn được từng bảng bằng pg_restore.
# Auth qua unix socket trong container nên không cần mật khẩu.
docker exec "$CONTAINER" pg_dump -U "$DB_USER" -Fc "$DB" >"${file}.part"
mv "${file}.part" "$file"
chmod 0640 "$file"

echo "pg_backup: $(du -h "$file" | cut -f1) -> $file"

if [[ -n "${BACKUP_S3_URI:-}" ]]; then
  if command -v aws >/dev/null 2>&1; then
    aws s3 cp --only-show-errors "$file" "${BACKUP_S3_URI%/}/$(basename "$file")"
    echo "pg_backup: đã lên ${BACKUP_S3_URI%/}/$(basename "$file")"
  else
    # Không im lặng bỏ qua: backup tưởng là đang lên S3 mà thực ra không,
    # đúng loại lỗi chỉ phát hiện ra vào lúc cần restore.
    echo "pg_backup: có BACKUP_S3_URI nhưng thiếu aws CLI (apt-get install -y awscli)" >&2
    exit 1
  fi
fi

# Dọn bản cũ. Chỉ dọn ở local — bản trên S3 để lifecycle rule của bucket lo.
find "$DEST" -name "${DB}-*.dump" -type f -mtime "+${KEEP_DAYS}" -delete

# Restore (ghi đè database đang có, App phải dừng trước):
#   kamal app stop
#   cat <file>.dump | docker exec -i travelog-db pg_restore -U location_project \
#     -d location_project_production --clean --if-exists --no-owner
#   kamal app boot
