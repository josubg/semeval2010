#!/usr/bin/env python3

import os
import sys
import argparse
import subprocess


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
        '--system', dest='systems',  nargs='*', default=["relaxcor", "sucre", "tanl-1", "ubui"],
        choices=["relaxcor", "sucre", "tanl-1", "ubui"],
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


def process(languages, information, annotations, systems, scripts, results_path, gold_path, metrics):
    flat_metric = [(m, k) for m in metrics for k in ("R", "P", "F1")]
    with open("README.md", "w") as output:
        with open("preface.md") as pref:
            for script in scripts:
                output.writelines(pref.readlines())
                for language in languages:
                    output.write("#### Language {}\n".format(language))
                    for annotation in annotations:
                        origin = os.path.join(results_path, language) + "_test_auto.conll"
                        if not os.path.exists(origin):
                            print("File does not exist: {}".format(origin), file=sys.stderr)
                            continue
                        for inf in information:
                            section = ""
                            for system in systems:
                                destiny = os.path.join(gold_path, system, inf, annotation, language) + ".txt.conll"
                                if not os.path.exists(destiny):
                                    # output.write("| {} | Not reported |\n".format(system, destiny))
                                    continue
                                command = ["sh", "script/eval/eval_{}.sh".format(script), origin, destiny]

                                p = subprocess.Popen(
                                    command,  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                                pipe, err = p.communicate(results_path)
                                if err:
                                    print("| {} | Error reported|".format(system), file=sys.stderr)
                                    sys.stderr.write(err.decode("utf-8"))
                                else:
                                    results_string = pipe.decode("utf-8")
                                    results = dict(zip(flat_metric, results_string.split(", ")))
                                    results[("semeval", "R")] = "{0:.2f}".format(
                                        (float(results[("muc", "R")]) +
                                         float(results[("bcub", "R")]) +
                                         float(results[("ceafm", "R")])
                                         )/3)
                                    results[("semeval", "P")] = "{0:.2f}".format(
                                        (float(results[("muc", "P")]) +
                                         float(results[("bcub", "P")]) +
                                         float(results[("ceafm", "P")])
                                         )/3)
                                    results[("semeval", "F1")] = "{0:.2f}".format(
                                        (float(results[("muc", "F1")]) +
                                         float(results[("bcub", "F1")]) +
                                         float(results[("ceafm", "F1")])
                                         )/3)
                                    print(results)
                                    section += "| " + \
                                               " | ".join(
                                                   [system] +
                                                   [results[m]
                                                    for m in
                                                    flat_metric + [
                                                        ("semeval", "R"), ("semeval", "P"), ("semeval", "F1")]]) + \
                                               "|\n"
                            if section:
                                output.write("##### Information: {} annotation: {}\n".format(inf, annotation))
                                output.write(header(metrics))
                                output.write(section)


if __name__ == '__main__':
    process(**vars(parse_cmd_arguments()))
