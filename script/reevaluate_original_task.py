#!/usr/bin/env python3

import os
import shutil
import sys
import argparse
import subprocess

CLEAR ='\x1b[0m'
RED = '\x1b[1;34;0m'
YELLOW = '\x1b[1;33;0m'
GREEN = '\x1b[1;32;0m'
WHITE = '\x1b[1;37;0m'


def parse_cmd_arguments():
    """ Get the necessary metadata to complete the KAF."""
    parser = argparse.ArgumentParser(
        description="Process a CONLL file into a kaf one")
    parser.add_argument(
        '--language',  dest='languages',  nargs='*', default=["es", "it", "ca"],
        help="Language to process")
    parser.add_argument(
        '--information', dest='information',  nargs='*', default=["open", "closed"],
        choices=["open", "closed"],
        help="Language to process")
    parser.add_argument(
        '--system', dest='systems',  nargs='*', default=["relaxcor", "sucre", "tanl-1", "ubiu"],
        choices=["relaxcor", "sucre", "tanl-1", "ubiu"],
        help="Language to process")
    parser.add_argument(
        '--annotation', dest='annotations', nargs='*', default=["gold", "regular"],
        choices=["gold", "regular"],
        help="Language to process")
    parser.add_argument(
        '--script', dest='scripts',  nargs='*', default=["v8", "semeval_official"],
        choices=["v8", "semeval_official"],
        help="Language to process")
    parser.add_argument(
        '--results_path', dest='results_path', action='store', default="./corpora/flat",
        help="Language to process")
    parser.add_argument(
        '--gold_path', dest='gold_path', action='store', default="./original_task",
        help="Language to process")
    parser.add_argument(
        '--metrics', dest='metrics', nargs="*", action='store', default=["MD", "ceafm", "muc", "bcub", "blanc"],
        help="Language to process")

    return parser.parse_args()


def header(metrics):
    return '\n|  | ' + ' |  |  | '.join(metrics + ["Semeval"]) + ' | | |\n' +\
        '| ' + ' | '.join(["---"] * 19) + ' |\n' + \
        '| ' + ' | '.join(["system"] + ["R", "P", "F1"] * 6) + ' |\n'


def evaluate_system(metrics, origin, destiny, prefix):
    error = False
    results = {}
    for metric in metrics:
        if metric == "MD":
            # Calculate mention detection with fastest metric
            m = "muc"
        else:
            m = metric
        p = subprocess.Popen(
           ["perl",  "./scorer/v8.01/scorer.pl",  m,  origin, destiny],
           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        pipe, err = p.communicate()
        if err:
            error = True
            results[metric, "R"] = float("Nan")
            results[metric, "P"] = float("Nan")
            results[metric, "F1"] = float("Nan")
            print("Error at {} ".format(metric), end='')
            with open(prefix+"{}_error.txt".format(metric), "w") as err_file:
                err_file.write(err.decode("utf-8"))
        else:
            evaluation = pipe.decode("utf-8")
            with open(prefix + "{}_evaluation.txt".format(metric), "w") as eval_file:
                eval_file.write(evaluation)

            if metric == "MD":
                line, r_index, p_index, f1_index = -5, -4, -3, -2
            else:
                line, r_index, p_index, f1_index = -3, -4, -3, -2

            tokens = evaluation.split("\n")[line].split("%")
            results[metric, "R"] = float(tokens[r_index].split(" ")[-1])
            results[metric, "P"] = float(tokens[p_index].split(" ")[-1])
            results[metric, "F1"] = float(tokens[f1_index].split(" ")[-1])
            with open(prefix + "{}_evaluation.txt".format(metric), "w") as eval_file:
                eval_file.write(evaluation)

    return results, error


def calculate_semeval(results):
    try:
        results[("semeval", "R")] = ((results[("muc", "R")] + results[("bcub", "R")] + results[("ceafm", "R")]) / 3)
        results[("semeval", "P")] = ((results[("muc", "P")] + results[("bcub", "P")] + results[("ceafm", "P")]) / 3)
        results[("semeval", "F1")] = ((results[("muc", "F1")] + results[("bcub", "F1")] + results[("ceafm", "F1")]) / 3)
        return False
    except KeyError:
        results[("semeval", "R")] = float("NaN")
        results[("semeval", "P")] = float("NaN")
        results[("semeval", "F1")] = float("NaN")
        print("Error at Semeval ", end='')
        return True


def process(languages, information, annotations, systems, scripts, results_path, gold_path, metrics):
    flat_metric = [(m, k)
                   for m in (metrics + ["semeval"])
                   for k in ("R", "P", "F1")]

    with open("README.md", "w") as output:
        with open("preface.md") as pref:
            for script in scripts:
                output.writelines(pref.readlines())
                for language in languages:
                    shutil.rmtree(os.path.join("log", language), ignore_errors=True)
                    os.makedirs(os.path.join("log", language))
                    output.write("#### Language {}\n".format(language))
                    print("Language {}".format(language))
                    for annotation in annotations:
                        origin = os.path.join(results_path, language) + "_test_auto.conll"
                        if not os.path.exists(origin):
                            print("File does not exist: {}".format(origin), file=sys.stderr)
                            continue
                        for inf in information:
                            print("\tsection:    " + WHITE + "{:>8}".format(inf) + CLEAR)
                            print("\tannotation: " + WHITE + "{:>8}".format(annotation) + CLEAR)
                            results = {}
                            for system in systems:
                                print("\t\t{:.<15}...".format(system), end='')
                                destiny = os.path.join(gold_path, system, inf, annotation, language) + ".txt.conll"
                                if not os.path.exists(destiny):
                                    print("{:.>15}".format(YELLOW+"Not reported " + CLEAR))
                                else:
                                    prefix = "log/{}/{}_{}_{}".format(language, inf, annotation, system)
                                    results[system], error = evaluate_system(metrics, origin, destiny, prefix)
                                    error |= calculate_semeval(results[system])
                                    if error:
                                        print("{:.>15}".format(RED + "Error" + CLEAR))
                                    else:

                                        print("{:.>15}".format(GREEN + "Processed" + CLEAR))
                            if results:
                                output.write("##### Information: {} annotation: {}\n".format(inf, annotation))
                                output.write(header(metrics))
                                for system, system_results in results.items():
                                    output.write(
                                        "| {} | ".format(system) +
                                        " | ".join("{0:.2f}".format(system_results[m]) for m in flat_metric) +
                                        " |\n")


if __name__ == '__main__':
    process(**vars(parse_cmd_arguments()))
