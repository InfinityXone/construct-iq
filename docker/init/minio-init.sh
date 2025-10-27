#!/bin/sh
set -euo pipefail

: "${MINIO_ROOT_USER:=ciqadmin}"
: "${MINIO_ROOT_PASSWORD:=ciqadminpass}"
: "${MINIO_BUCKET:=docs}"

echo "MinIO init: user=${MINIO_ROOT_USER} bucket=${MINIO_BUCKET}"

# wait for MinIO and create bucket (retry)
i=0
until mc alias set local http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null 2>&1; do
  i=$((i+1))
  [ $i -ge 60 ] && echo "MinIO not reachable" >&2 && exit 1
  echo "Waiting for MinIO… ($i/60)"; sleep 2
done

mc mb --ignore-existing "local/${MINIO_BUCKET}" >/dev/null 2>&1 || true
echo "Bucket '${MINIO_BUCKET}' ready"
