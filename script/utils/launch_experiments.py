#!/usr/bin/python3
# coding=utf-8
""" A script to ease the process of a corpus into a series of tool chains.
Specially useful for serial experiment.
"""

import subprocess
import configargparse
import logging
import codecs
import os
import pycorpus

__author__ = 'Josu Bermudez <josu.bermudez@deusto.es>'


LOGGER = logging.getLogger(__name__)


def generate_process_parser():
    """  Generate a argument parser to be used in pycorpus.
    This parser provides all de config needed to run the script.
    """

    parser = configargparse.ArgumentParser(
        prefix_chars="-", config_file_parser_class=configargparse.YAMLConfigFileParser)
    parser.add_argument(
        '--config', '-c', is_config_file=True,
        help='config file path')
    parser.add_argument(
        '--language', dest='language', action='store', default="en",
        help="The language passed to tools in the chain ")
    parser.add_argument(
        '--encoding', dest='encoding', action='store', default="UTF-8",
        help="The encoding")
    parser.add_argument(
        '--encoding_out', dest='encoding_out', action='store', default="UTF-8",
        help="The encoding")
    parser.add_argument(
        '--chain', nargs='*', dest='chain', action='append', default=[],
        help="The Chain that process the files")
    parser.add_argument(
        '--step', nargs='*', dest='steps', action='append',default=[],
        help="The Chain that process the files")
    parser.add_argument(
        '--output', dest='output', action='store', default="",
        help="Extension of the final file. If not set not stored")
    return parser


def define_chains(steps, options, file_name):
    """ Define all possible tool chains usable to process the corpus.

    :param file_name: The
    :param steps: The list of steps to build.
    :param options: A object that contains the additional attributes for steps.
    """
    steps_dict = dict()
    for step in steps:
        steps_dict[step[0]] = [
            param.format(options=options, file_name=file_name) for param in step[1:]
        ]
    return steps_dict


def process_step(name, pipe, step_name, steps):
    step = steps[step_name]
    step_command = step[0]
    step_output = False
    if len(step) > 1:
        step_output = step[1]
        try:
            LOGGER.debug("Removing old version: %s", step_output)
            os.remove(step_output)
        except IOError as ex:
            LOGGER.debug("Fail erasing file %s", ex.message)

    # launch the command
    LOGGER.debug("Command: %s", step_command)
    try:
        p = subprocess.Popen(
            step_command.split(), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        pipe, err = p.communicate(pipe)
        # Check for errors
        if p.returncode:
            raise Exception("Error Processing{0}: {1}".format(name, err))
    except OSError:
        raise Exception("Pipe Failed in step {0}: {1}".format(step_name, OSError.message))
    # store the result
    if step_output:
        with codecs.open(step_output, "w") as output_file:
            output_file.write(pipe)
        LOGGER.info("Writing Step:  %s", step_output)
    return pipe


def process_file(file_name, config):
    """ This is the function to be launch by the PPSS script

    :param file_name: The file to be processed
    :param config: The parameters that affect the processing
    """

    #path, full_name = os.path.split(file_name)
    name, ext = os.path.splitext(file_name)
    encoding = config.encoding

    steps = define_chains(
        steps=config.steps, options=config, file_name=file_name)

    LOGGER.info("Reading: %s", file_name)
    try:
        # Load File
        with codecs.open(file_name, mode='r', encoding=encoding) as input_file:
            # pipe = input_file.read()
            pipe = input_file.read().encode()

        try:
            # Process each step
            for chain in config.chain:
                for step in chain:
                    pipe = process_step(
                        name, pipe, step, steps)
            # Store the final result
            try:
                if config.output:
                    joint_name = name + config.output
                    with codecs.open(joint_name, "w") as output_file:
                        if pipe is str:
                            output_file.write(pipe)
                        else:
                            output_file.write(pipe.decode(config.encoding_out))
                    LOGGER.info("Writen  %s", joint_name)
            except Exception as ex:
                LOGGER.exception("Fail Writing %s", file_name)
        except Exception as ex:
            LOGGER.exception("Fail Processing %s | %s | %s", file_name, ex, step)
    except Exception as ex:
        LOGGER.exception("Fail Reading %s", file_name)


if __name__ == "__main__":
    logging.basicConfig(level=logging.ERROR)
    corpus_processor = pycorpus.CorpusProcessor(
        generate_process_parser, process_file)
    corpus_processor.run_corpus()
