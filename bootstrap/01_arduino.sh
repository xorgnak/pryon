#!/bin/bash

if [[ -d ~/arduino ]]; then
    echo "arduino cli already installed."
    exit 0;
fi    

mkdir ~/arduino

curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh > arduino-install.sh

sh arduino-install.sh;

sudo cp bin/arduino-cli /bin/arduino-cli

rm arduino-install.sh;

cat<<EOF>~/.arduino15/arduino-cli.yaml
board_manager:
  additional_urls: ["https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json", "https://github.com/Heltec-Aaron-Lee/WiFi_Kit_series/releases/download/..7/package_heltec_esp32_index.json"]
build_cache:
  compilations_before_purge: 10
  ttl: 720h0m0s
daemon:
  port: "50051"
directories:
  data: /home/$USER/.arduino15
  downloads: /home/$USER/.arduino15/staging
  user: /home/$USER/Arduino
library:
  enable_unsafe_install: false
logging:
  file: ""
  format: text
  level: info
metrics:
  addr: :9090
  enabled: true
output:
  no_color: false
sketch:
  always_export_binaries: false
updater:
  enable_notification: true
EOF

arduino-cli core update-index

arduino-cli core install esp32:esp32 Heltec-esp32:esp32



exit 0;
