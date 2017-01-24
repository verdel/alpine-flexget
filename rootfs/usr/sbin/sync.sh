#!/usr/bin/with-contenv bash

rm $FLEXGET_CONF_DIR/*.yml
cp $FLEXGET_SYNC_DIR/*.yml $FLEXGET_CONF_DIR
/usr/bin/flexget -c $FLEXGET_CONF_DIR/config.yml daemon reload