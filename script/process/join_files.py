#!/usr/bin/python
# coding=utf-8
""" Extract form a Conll corpus the original text separated by parts.
arguments :  config_subdirectory corpus_group corpus
"""

__author__ = 'Josu Bermudez <josu.bermudez@deusto.es>'
__created__ = '27/06/13'


import argparse
import logging
import codecs
import sys
import os
import io


class Joiner:

    def __init__(self):
        self.logger = logging.getLogger(__name__)

    @staticmethod
    def parse_cmd_arguments():
        """ Get the necessary metadata to complete the KAF."""
        parser = argparse.ArgumentParser(
            description="Process a CONLL file into a kaf one")
        parser.add_argument(
            '--file_name',  dest='file', action='store', default=None,
            help="File to process, if no determined used standard input.")
        parser.add_argument(
            '--encoding', '-e',
            dest='encoding', action='store', default="utf-8",
            help="Encoding of the file")

        return parser.parse_args()

    def process_file(
            self, file_name, encoding ):
        """Split the file in part extract the info and store in different naf
        files. One per part.

        :param encoding: The encoding of the original File.
        :param file_name: The path of the Conll file.
        """
        self.logger.info("Start processing file: {0}".format(file_name))
        base, ext = os.path.splitext(file_name)
        # File Names patterns(For parts)
        coref_name = base + ".coref"
        # The parts_size of a file , the speakers of each part, the tokens
        # of each part.
        in_stream = io.TextIOWrapper(sys.stdin.buffer, encoding=encoding)
        # in_stream = codecs.getreader(encoding)(sys.stdin)
        out_stream = io.TextIOWrapper(sys.stdout.buffer, encoding=encoding)
        # out_stream = codecs.getwriter(encoding)(sys.stdout)

        with codecs.open(coref_name, "r", encoding=encoding) as coref_file:
            # Write part in NAF format
            naf = in_stream.read()
            new_end = coref_file.read()
            new_end += u"</NAF>"
            new_file = naf.replace(u"</NAF>", new_end)
            out_stream.write(new_file)

        self.logger.info(
            "joined{0} {1} parts".format(file_name, coref_name))


if __name__ == "__main__":
    logging.basicConfig(
        stream=sys.stderr, format='%(levelname)s - %(message)s',
        level=logging.DEBUG)
    logger = logging.getLogger(__name__)
    try:
        parameters = Joiner.parse_cmd_arguments()
        extractor = Joiner()
        extractor.process_file(
            file_name=parameters.file,
            encoding=parameters.encoding,
            )
    except Exception as error:
        logger.exception("Unexpected error")
        exit(-1)
