#!/usr/bin/with-contenv bash

WATCH_DIR="$FLEXGET_SYNC_DIR"
SETTLE_DURATION=60
MAX_WAIT_TIME=60
IGNORE_EVENTS_WHILE_COMMAND_IS_RUNNING=1

#-----------------------------------------------------------------------------------------------------------------------

function wait_for_events_to_stabilize {
  start_time=$(date +"%s")

  while true
  do
    if read -t $SETTLE_DURATION RECORD
    then
      end_time=$(date +"%s")

      if [ $(($end_time-$start_time)) -gt $MAX_WAIT_TIME ]
      then
        echo "[Flexget-Inotify-Sync] Input directory didn't stabilize after $MAX_WAIT_TIME seconds. Triggering command anyway."
        break
      fi
    else
      echo "[Flexget-Inotify-Sync] Input directory stabilized for $SETTLE_DURATION seconds. Triggering command."
      break
    fi
  done
}

#-----------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------------------------------

function wait_for_command_to_complete {
  PID=$1

  while [ -e /proc/$PID ]
  do
    sleep .1

    if [[ "$IGNORE_EVENTS_WHILE_COMMAND_IS_RUNNING" == "1" ]]
    then
      # -t 0 didn't work for me. Seemed to return success with no RECORD
      while read -t 1 RECORD; do :; done
    fi
  done
}

#-----------------------------------------------------------------------------------------------------------------------

pipe=$(mktemp -u)
mkfifo $pipe

echo "[Flexget-Inotify-Sync] Waiting for changes to $WATCH_DIR..."
inotifywait -r -m -q --format 'EVENT=%e FILE=%w%f' $WATCH_DIR >$pipe &

while true
do
  if read RECORD
  then
    EVENT=$(echo "$RECORD" | sed 's/EVENT=\([^ ]*\).*/\1/')
    FILE=$(echo "$RECORD" | sed 's/EVENT=.* FILE=\([^ ]*\).*/\1/')
    if [[ $FILE == *"yml"* ]]; then

      # Monster up as many events as possible, until we hit the either the settle duration, or the max wait threshold.
      wait_for_events_to_stabilize
      /usr/sbin/sync.sh &
      PID=$!
      wait_for_command_to_complete $PID

    fi
  fi
done <$pipe
