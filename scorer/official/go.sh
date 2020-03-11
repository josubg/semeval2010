#!/usr/bin/env bash
gold_path=$1
response_path=$2
response_ext=$3
metric=$4
gold_ext=$5
find ${response_path} -name "*.${response_ext}" | sort | xargs cat  > buff.res.conll.${response_ext}
find ${response_path} -name "*.${response_ext}" | sort  > buff.res_list.conll.${response_ext}
find ${gold_path} -name "*.${gold_ext}" | sort > buff.key_list.conll.${response_ext}
find ${gold_path} -name "*.${gold_ext}" | sort | xargs cat | sed "s/\.tbf\.xml//g"  > buff.key.conll.${response_ext}
./scorer.pl $metric buff.key.conll.${response_ext} buff.res.conll.${response_ext} $files
