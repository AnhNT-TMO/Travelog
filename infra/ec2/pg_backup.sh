#!/bin/bash
set -euo pipefail

CONTAINER=travelog-db
DB=travelog_production
DB_USER=travelog
DEST=/var/lib/travelog/backups
KEEP_DAYS=7

ENV_FILE=/etc/travelog-backup.env
[[ -f $ENV_FILE ]] && set -a && . "$ENV_FILE" && set +a

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
file="${DEST}/${DB}-${stamp}.dump"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "pg_backup: container $CONTAINER không chạy" >&2
  exit 1
fi

mkdir -p "$DEST"

docker exec "$CONTAINER" pg_dump -U "$DB_USER" -Fc "$DB" >"${file}.part"
mv "${file}.part" "$file"
chmod 0640 "$file"

echo "pg_backup: $(du -h "$file" | cut -f1) -> $file"

if [[ -n "${BACKUP_S3_URI:-}" ]]; then
  if command -v aws >/dev/null 2>&1; then
    aws s3 cp --only-show-errors "$file" "${BACKUP_S3_URI%/}/$(basename "$file")"
    echo "pg_backup: đã lên ${BACKUP_S3_URI%/}/$(basename "$file")"
  else
    echo "pg_backup: có BACKUP_S3_URI nhưng thiếu aws CLI (apt-get install -y awscli)" >&2
    exit 1
  fi
fi

find "$DEST" -name "${DB}-*.dump" -type f -mtime "+${KEEP_DAYS}" -delete
