#!/bin/bash

function repo() {
if [[ -z "$1" ]]; then
    echo "specify directory to create."
    exit 0;
fi

if [[ -d "$1" ]]; then
    echo "directory already exists."
    exit 0;
fi
    
if [[ -z "$2" ]]; then
    echo "specify scripting language."
    exit 0;
fi

sudo adduser git

mkdir $1

cd $1

git init

git remote add home git@127.0.0.1:/home/git/$1.git

cat <<EOF>> README.md
# `pwd` project
## created at: `date`
## written in: $2
### all rights reserved.


# CONTENTS
src/ -> source to be compiled.
lib/ -> script library files.
bin/ -> scripts that initialize.
exe/ -> utility scripts.
bootstrap/ -> installation scripts.
views/ -> html templates.
public/ -> hosted files.
EOF

mkdir src lib lib/$1 bin exe bootstrap views public

touch bin/init

cat<<EOF>> config.sh
IN='$2';
EOF

cat<<EOF>> start
source config.sh;
$IN bin/init;
EOF

chmod +x start

touch README.md

git add .

git commit -m 'first commit.'

sudo su -c "cd ~ && mkdir $1.git && cd $1.git && git init --bare" git

git push home master

}
