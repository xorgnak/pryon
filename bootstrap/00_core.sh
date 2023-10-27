#!/bin/bash

if [[ -f ~/.screenrc ]]; then
    echo "core already installed.";
    exit 0;
fi

sudo apt update

sudo apt upgrade -q

sudo apt install -q $Z4_PKGS

if [[ -z "$USERLAND" ]]; then
    sudo apt install -q $Z4_PKGS_USERLAND
fi

cat <<EOF>~/.screenrc
shell -/bin/bash
caption always "[ %H ] %w"
defscrollback 1024
startup_message off
hardstatus on
hardstatus alwayslastline
screen -t '#' 0 emacs -nw --funcall erc --visit ~/index.org
screen -t '>' 1 /bin/bash
select 1
EOF

exit 0;
