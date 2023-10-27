#!/bin/bash

export BRAND='propedicab.com';
export COHORT='PRYONS';
export NODE="`hostname`";
export Z4_NAME='main tui';
export Z4_VERSION='0.3.5';
export Z4_PKGS_SYS='screen ruby-full lua5.3 build-essential nginx libnginx-mod-rtmp mosquitto';
export Z4_PKGS_EDITORS_EMACS='emacs-nox';
export Z4_PKGS_EDITORS_VIM='vim';
export Z4_PKGS_EDITORS_MICRO='micro';
export Z4_PKGS_TOOLS='calcurse remind when taskwarrior timewarrior';
export Z4_PKGS_UTILS='nmap';
export Z4_PKGS_USERLAND='bluetoothctl';
export Z4_PKGS="$Z4_PKGS_SYS $Z4_PKGS_EDITORS_EMACS $Z4_PKGS_EDITORS_VIM $Z4_PKGS_EDITORS_MICRO $Z4_PKGS_TOOLS $Z4_PKGS_UTILS";
