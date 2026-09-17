#!/usr/bin/env bash
# 在 wks 上執行：備份資料庫、拉最新程式碼、依 VERSION 同步 compose 版本號、重建並重啟 twsub2api。
# 用法：bash /home/orz99/zoo/sub2api.TW/deploy/wks-update.sh
# 說明：deploy/WKS.md
set -euo pipefail
REPO=/home/orz99/zoo/sub2api.TW
STACK=/home/orz99/zoo
SVC=twsub2api
STAMP=$(date +%Y%m%d-%H%M)

cd "$REPO"
echo "== git pull（只接受 fast-forward）=="
git pull --ff-only
COMMIT=$(git rev-parse --short HEAD)
VERSION="v$(tr -d '\r\n' < backend/cmd/server/VERSION)"
echo "== 程式碼版本：$VERSION（$(git log -1 --format='%h %ci %s')）"

cd "$STACK"
OLD=$(sed -n "/^  $SVC:/,/^  [a-z]/s#.*image: dado/twsub2api:\(v[0-9.]*\).*#\1#p" docker-compose.yml)
echo "== compose 目前版本：$OLD"

echo "== 備份資料庫 =="
mkdir -p backups
docker exec postgresql_db sh -c 'pg_dump -U "$POSTGRES_USER" -Fc sub2api' > "backups/sub2api-$OLD-$STAMP.dump"
ls -la "backups/sub2api-$OLD-$STAMP.dump"

if [ "$OLD" != "$VERSION" ]; then
  echo "== 版本變更 $OLD → $VERSION，更新 compose =="
  cp -a docker-compose.yml "docker-compose.yml.bak-$STAMP"
  sed -i "/^  $SVC:/,/^  [a-z]/{s#dado/twsub2api:$OLD#dado/twsub2api:$VERSION#;s#VERSION=$OLD#VERSION=$VERSION#}" docker-compose.yml
  docker compose config -q
fi

echo "== 重建映像（Dockerfile 預設的 goproxy.cn 在 wks 會斷線，改用官方鏡像）=="
GIT_COMMIT="$COMMIT" docker compose build \
  --build-arg GOPROXY=https://proxy.golang.org,direct \
  --build-arg GOSUMDB=sum.golang.org \
  "$SVC"

echo "== 重啟容器（--no-deps：不動共用的 postgres、redis）=="
docker compose up -d --no-deps "$SVC"
for _ in $(seq 1 24); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$SVC")" = healthy ] && break
  sleep 5
done
docker compose ps "$SVC"
docker exec nginx_proxy curl -s -o /dev/null -w "nginx_proxy → $SVC /health HTTP %{http_code}\n" "http://$SVC:8080/health"
