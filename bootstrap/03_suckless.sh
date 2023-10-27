#!/bin/bash

echo "[SUCKLESS] installing..."

cd ~
echo "[SUCKLESS][9base] installing..."
git clone https://git.suckless.org/9base
cd 9base
make clean
sudo make install
echo "[SUCKLESS][9base] installed."

cd ~
echo "[SUCKLESS][grapheme] installing..."
git clone https://git.suckless.org/libgrapheme
cd libgrapheme
./configure
make clean
sudo make install
echo "[SUCKLESS][grapheme] installed."

cd ~
echo "[SUCKLESS][lchat] installing..."
git clone https://git.suckless.org/lchat
cd lchat
make clean
sudo make install
echo "[SUCKLESS][lchat] installed."

cd ~
echo "[SUCKLESS][quark] installing..."
git clone https://git.suckless.org/quark
cd quark
sudo make install
echo "[SUCKLESS][quark] installed."

cd ~
echo "[SUCKLESS][dmenu] installing..."
git clone git://git.suckless.org/dmenu
cd dmenu
make clean
sudo make clean install
echo "[SUCKLESS][dmenu] installed."

cd ~
echo "[SUCKLESS][dwm] installing..."
git clone git://git.suckless.org/dwm
cd dwm
make clean
sudo make clean install
echo "[SUCKLESS][dwm] installed."

cd ~
echo "[SUCKLESS][sic] installing..."
git clone git://git.suckless.org/sic
cd sic
make clean
make
sudo make install
echo "[SUCKLESS][sic] installed."

cd ~
echo "[SUCKLESS][ii] installing..."
git clone git://git.suckless.org/ii
cd ii
make clean
make
sudo cp ii /bin/ii
echo "[SUCKLESS][ii] installed."

cd ~
echo "[SUCKLESS][farbfeld] installing..."
git clone https://git.suckless.org/farbfeld
cd farbfeld
make clean
make
sudo make install
echo "[SUCKLESS][farbfeld] installed."

cd ~
echo "[SUCKLESS][sent] installing..."
git clone https://git.suckless.org/sent
cd sent
make clean
make
sudo make install 
echo "[SUCKLESS][sent] installed."

echo "[SUCKLESS] installed."
