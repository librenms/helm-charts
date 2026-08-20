#!/bin/sh
TARGET="/data/env-volume/env"
echo "Target: $TARGET"
echo "APP_KEY=$(cat /data/key/appkey)" > $TARGET
echo "NODE_ID=$(hostname)" >> $TARGET

# Laravel only reads these from .env; PHP-FPM runs with clear_env=yes so
# container env vars are invisible to it after a config cache clear.
if [ -n "$APP_URL" ]; then
  echo "APP_URL=$APP_URL" >> $TARGET
fi

if [ -n "$APP_TRUSTED_PROXIES" ]; then
  echo "APP_TRUSTED_PROXIES=$APP_TRUSTED_PROXIES" >> $TARGET
fi

cat $TARGET
