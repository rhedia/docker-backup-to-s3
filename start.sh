#!/bin/bash

set -e

: ${S3_PATH:?"S3_PATH env variable is required"}
export DATA_PATH=${DATA_PATH:-/data/}
CRON_SCHEDULE=${CRON_SCHEDULE:-0 1 * * *}

if [[ -n "$ACCESS_KEY_FILE" ]]; then
    if [[ -n "$ACCESS_KEY" ]]; then
        echo "error : ACCESS_KEY and ACCESS_KEY_FILE are both set. Use one of the two"
    else
        ACCESS_KEY=$(cat "$ACCESS_KEY_FILE")
    fi
fi

if [[ -n "$SECRET_KEY_FILE" ]]; then
    if [[ -n "$SECRET_KEY" ]]; then
        echo "error : SECRET_KEY and SECRET_KEY_FILE are both set. Use one of the two "
    else
        SECRET_KEY=$(cat "$SECRET_KEY_FILE")
    fi
fi

if [[ -n "$ACCESS_KEY"  &&  -n "$SECRET_KEY" ]]; then
    echo "access_key=$ACCESS_KEY" >> /root/.s3cfg
    echo "secret_key=$SECRET_KEY" >> /root/.s3cfg
else
    echo "No ACCESS_KEY and SECRET_KEY env variable found, assume use of IAM"
fi

if [[ "$1" == 'no-cron' ]]; then
    exec /sync.sh
elif [[ "$1" == 'get' ]]; then
    exec /get.sh
elif [[ "$1" == 'delete' ]]; then
    exec /usr/local/bin/s3cmd del -r "$S3_PATH"
else
    LOGFIFO='/var/log/cron.fifo'
    if [[ ! -e "$LOGFIFO" ]]; then
        mkfifo "$LOGFIFO"
    fi
    CRON_ENV="PARAMS='$PARAMS'"
    CRON_ENV="$CRON_ENV\nDATA_PATH='$DATA_PATH'"
    CRON_ENV="$CRON_ENV\nS3_PATH='$S3_PATH'"
    echo -e "$CRON_ENV\n$CRON_SCHEDULE /sync.sh > $LOGFIFO 2>&1" | crontab -
    crontab -l
    cron
    tail -f "$LOGFIFO"
fi
