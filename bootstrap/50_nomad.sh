#!/bin/bash

echo "[NOMAD] installing..."

sudo su -c "echo '(screen -Dr || screen)' > /usr/bin/nomad";

sudo chmod 777 /usr/bin/nomad

echo "[NOMAD] installed."

exit 0
