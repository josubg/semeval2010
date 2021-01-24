#!/usr/bin/env bash

bold=$(tput bold)
normal=$(tput sgr0)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)


if [[ $# -ne 2 ]]; then
    echo "${RED}Please provide 2 parameters ${normal}${bold} USAGE  process.sh test|train es|ca|it ${normal}"
    exit 2
fi

corpus=$1
case ${corpus} in
    test|train) echo "${bold}selected corpus ${BLUE} ${corpus} ${normal}";;
    *)          echo "${RED} Not valid Corpus ${bold} ${corpus} ${normal}" && exit 1;;
esac


lang=$2
case ${lang} in
    es|it|ca) echo "${bold}Selected Lang ${BLUE} ${lang} ${normal}";;
    *)        echo "${RED}Not valid Lang ${bold} ${lang} ${normal}" && exit 1;;
esac


# clean
rm -r log
mkdir log

CORPUS_PATH=./corpora/${corpus}/${lang}
TASK_PATH=./configurations/task/${lang}/${corpus}

rm -rf ${CORPUS_PATH}
mkdir -p ${CORPUS_PATH}
mkdir -p ${CORPUS_PATH}/gold
mkdir -p ${CORPUS_PATH}/auto
mkdir -p ${CORPUS_PATH}/all
mkdir -p ${CORPUS_PATH}/flat

# Extract Semeval format file into several NAF files
echo "${bold}Extracting ${corpus} ${lang} AUTO ${normal}"
script/utils/launch_experiments.py -p ${TASK_PATH}/extract_auto.yaml
echo "${bold}Extracting ${corpus} ${lang} GOLD ${normal}"
script/utils/launch_experiments.py -p ${TASK_PATH}/extract_gold.yaml

# POS and syntactic parse from NAF to NAF
echo "${bold}POS and PARSE  ${corpus} ${lang} AUTO ${normal}"
script/utils/launch_experiments.py -p ${TASK_PATH}/parse_auto.yaml
echo "${bold}POS and PARSE  ${corpus} ${lang} GOLD ${normal}"
script/utils/launch_experiments.py -p ${TASK_PATH}/parse_gold.yaml

# Join the previous files with the additional files obtained from extraction
echo "${bold}JOIN parse and coref ${corpus} ${lang} AUTO ${normal}"
script/utils/launch_experiments.py -p ${TASK_PATH}/join_auto.yaml
echo "${bold}JOIN parse and coref ${corpus} ${lang} GOLD ${normal}"
script/utils/launch_experiments.py -p ${TASK_PATH}/join_gold.yaml

# Convert the final file into CoNLL annotation
echo "${bold}Convert to conll2012 ${corpus} ${lang} AUTO ${normal}"
script/utils/launch_experiments.py -p ${TASK_PATH}/convert_naf_to_conll_auto.yaml
echo "${bold}Convert to conll2012 ${corpus} ${lang} GOLD ${normal}"
script/utils/launch_experiments.py -p ${TASK_PATH}/convert_naf_to_conll_gold.yaml

## Convert the final file into Freeling compatible annotation
#echo Convert to conll2012 ${corpus} ${lang} AUTO
#./script/launch_experiments.py -p ./configurations/task/${lang}convert_naf_to_freeling_auto.yaml
#echo Convert to conll2012 ${corpus} ${lang} GOLD
#./script/launch_experiments.py -p ./configurations/task/${lang}convert_naf_to_freeling_gold.yaml

echo "${bold}Flat the corpus ${normal}"
script/process/flat_files.sh ${corpus} ${lang} auto
script/process/flat_files.sh ${corpus} ${lang} gold

echo "${bold}Clean intermediate files ${normal}"
find ${CORPUS_PATH}/ -name "*.enaf" -delete
find ${CORPUS_PATH}/ -name "*.coref" -delete
find ${CORPUS_PATH}/ -name "*.pnaf" -delete