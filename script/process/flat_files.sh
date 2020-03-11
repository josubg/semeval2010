#!/usr/bin/env bash


corpus=$1
echo ${corpus}
lang=$2
echo ${lang}
annotation=$3
echo ${annotation}

find corpora/${corpus}/${lang}/${annotation}/ -name "*.${annotation}_conll" -exec cat {}  \;> corpora/flat/${lang}_${corpus}_${annotation}.conll