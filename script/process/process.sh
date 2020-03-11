#!/usr/bin/env bash

corpus=$1
echo ${corpus}
lang=$2
echo ${lang}

# clean
rm -r log
mkdir log

CORPUS_PATH=./corpora/${corpus}/${lang}
TASK_PATH=./configurations/task/${lang}/${corpus}

rm -r ${CORPUS_PATH}
mkdir ${CORPUS_PATH}
mkdir ${CORPUS_PATH}/gold
mkdir ${CORPUS_PATH}/auto
mkdir ${CORPUS_PATH}/all
mkdir ${CORPUS_PATH}/flat

# Extract Semeval format file into several NAF files
echo Extracting ${corpus} ${lang} AUTO
script/utils/launch_experiments.py -p ${TASK_PATH}/extract_auto.yaml
echo Extracting ${corpus} ${lang} GOLD
script/utils/launch_experiments.py -p ${TASK_PATH}/extract_gold.yaml

# POS and syntactic parse from NAF to NAF
echo POS and PARSE  ${corpus} ${lang} AUTO
script/utils/launch_experiments.py -p ${TASK_PATH}/parse_auto.yaml
echo POS and PARSE  ${corpus} ${lang} GOLD
script/utils/launch_experiments.py -p ${TASK_PATH}/parse_gold.yaml

# Join the previous files with the additional files obtained from extraction
echo JOIN parse and coref ${corpus} ${lang} AUTO
script/utils/launch_experiments.py -p ${TASK_PATH}/join_auto.yaml
echo JOIN parse and coref ${corpus} ${lang} GOLD
script/utils/launch_experiments.py -p ${TASK_PATH}/join_gold.yaml

# Convert the final file into CoNLL annotation
echo Convert to conll2012 ${corpus} ${lang} AUTO
script/utils/launch_experiments.py -p ${TASK_PATH}/convert_naf_to_conll_auto.yaml
echo Convert to conll2012 ${corpus} ${lang} GOLD
script/utils/launch_experiments.py -p ${TASK_PATH}/convert_naf_to_conll_gold.yaml

## Convert the final file into Freeling compatible annotation
#echo Convert to conll2012 ${corpus} ${lang} AUTO
#./script/launch_experiments.py -p ./configurations/task/${lang}convert_naf_to_freeling_auto.yaml
#echo Convert to conll2012 ${corpus} ${lang} GOLD
#./script/launch_experiments.py -p ./configurations/task/${lang}convert_naf_to_freeling_gold.yaml

echo "Flat the corpus"
script/process/flat_files.sh ${corpus} ${lang} auto
script/process/flat_files.sh ${corpus} ${lang} gold

echo "Clean intermediate files"
find ${CORPUS_PATH}/ -name "*.enaf" -delete
find ${CORPUS_PATH}/ -name "*.coref" -delete
find ${CORPUS_PATH}/ -name "*.pnaf" -delete
