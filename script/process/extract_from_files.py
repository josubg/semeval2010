#!/usr/bin/python
# coding=utf-8
""" Extract form a Conll corpus the original text separated by parts.
arguments :  config_subdirectory corpus_group corpus
"""

import argparse
import io
import logging
import codecs
import sys
import os
import re
from pynaf import NAFDocument

__author__ = 'Josu Bermudez <josu.bermudez@deusto.es>'
__created__ = '27/06/13'


class Extractor:
    """ Extract separated KAF files from each part of conll documents.
    """

    CONLL_COLUMN_FOR_TOKEN_GOLD = 0
    CONLL_COLUMN_FOR_TOKEN_PREDICTED = 0
    CONLL_COLUMN_FOR_TEXT_GOLD = 1
    CONLL_COLUMN_FOR_TEXT_PREDICTED = 1
    CONLL_COLUMN_FOR_LEMMA_GOLD = 2
    CONLL_COLUMN_FOR_LEMMA_PREDICTED = 3
    CONLL_COLUMN_FOR_POS_GOLD = 4
    CONLL_COLUMN_FOR_POS_PREDICTED = 5
    CONLL_COLUMN_FOR_FEAT_GOLD = 6
    CONLL_COLUMN_FOR_FEAT_PREDICTED = 7
    CONLL_COLUMN_FOR_HEAD_GOLD = 8
    CONLL_COLUMN_FOR_HEAD_PREDICTED = 9
    CONLL_COLUMN_FOR_REL_GOLD = 10
    CONLL_COLUMN_FOR_REL_PREDICTED = 11
    CONLL_COLUMN_FOR_ENTITY_GOLD = 12
    CONLL_COLUMN_FOR_ENTITY_PREDICTED = 12
    CONLL_COLUMN_FOR_COREFERENCE_GOLD = -1
    CONLL_COLUMN_FOR_COREFERENCE_PREDICTED = -1

    def __init__(self, annotation):
        self.logger = logging.getLogger(__name__)
        self.annotation = annotation

        if self.annotation == "auto":
            self.logger.info("Predicted columns")
            self.CONLL_COLUMN_FOR_TOKEN = self.CONLL_COLUMN_FOR_TOKEN_PREDICTED
            self.CONLL_COLUMN_FOR_TEXT = self.CONLL_COLUMN_FOR_TEXT_PREDICTED
            self.CONLL_COLUMN_FOR_LEMMA = self.CONLL_COLUMN_FOR_LEMMA_PREDICTED
            self.CONLL_COLUMN_FOR_POS = self.CONLL_COLUMN_FOR_POS_PREDICTED
            self.CONLL_COLUMN_FOR_FEAT = self.CONLL_COLUMN_FOR_FEAT_PREDICTED
            self.CONLL_COLUMN_FOR_HEAD = self.CONLL_COLUMN_FOR_HEAD_PREDICTED
            self.CONLL_COLUMN_FOR_REL = self.CONLL_COLUMN_FOR_REL_PREDICTED
            self.CONLL_COLUMN_FOR_ENTITY = \
                self.CONLL_COLUMN_FOR_ENTITY_PREDICTED
            self.CONLL_COLUMN_FOR_COREFERENCE = \
                self.CONLL_COLUMN_FOR_COREFERENCE_PREDICTED
        elif self.annotation == "gold":
            self.CONLL_COLUMN_FOR_TOKEN = self.CONLL_COLUMN_FOR_TOKEN_GOLD
            self.CONLL_COLUMN_FOR_TEXT = self.CONLL_COLUMN_FOR_TEXT_GOLD
            self.CONLL_COLUMN_FOR_LEMMA = self.CONLL_COLUMN_FOR_LEMMA_GOLD
            self.CONLL_COLUMN_FOR_POS = self.CONLL_COLUMN_FOR_POS_GOLD
            self.CONLL_COLUMN_FOR_FEAT = self.CONLL_COLUMN_FOR_FEAT_GOLD
            self.CONLL_COLUMN_FOR_HEAD = self.CONLL_COLUMN_FOR_HEAD_GOLD
            self.CONLL_COLUMN_FOR_REL = self.CONLL_COLUMN_FOR_REL_GOLD
            self.CONLL_COLUMN_FOR_ENTITY = self.CONLL_COLUMN_FOR_ENTITY_GOLD
            self.CONLL_COLUMN_FOR_COREFERENCE = \
                self.CONLL_COLUMN_FOR_COREFERENCE_GOLD
        else:
            raise Exception("Unknown annotation $1", self.annotation)
        self.tid = 0
        self.ntid = 0
        self.edge_id = 0

    def _extract_parts_form_file(self, input_file):
        """ From a Conll file extract the part thar compound it.
         :param input_file: The stream of Conll file.
        """

        parts_sizes = []
        names = []
        parts = []
        part = []
        count = 0
        open_parts = 0
        closed_parts = 0
        for line in input_file:
            # Open part open file
            if line.startswith("#begin"):
                open_parts += 1
                count = 0
                names.append(line[16:-1].split('.')[0])
                part = []
            # Close part, close file
            elif line.startswith("#end"):
                closed_parts += 1
                parts_sizes.append(count)
                parts.append(part)
            # rest of lines input
            else:
                line = line.strip()
                if len(line) == 0:
                    count += 1
                    part.append([""] * 16)
                else:
                    columns = re.split(r'\s+', line)
                    part.append(columns)
        if open_parts != closed_parts:
            message = "Unaligned parts in: {0}/{1}".format(
                open_parts, closed_parts)
            self.logger.error(message)
            raise Exception(message)
        self.logger.info("Processed: %s", closed_parts)
        return parts_sizes, parts, names

    @staticmethod
    def _add_dependencies(dependencies, my_kaf):
        """ Add the dependencies tuples (origin, destiny,relation) to the kaf
        file.

        :param dependencies: A list with the tuples of the dependencies
        :param my_kaf: The kaf document where the tuples are going to be written
        """
        for dependency in dependencies:
            if dependency[1] != "ROOT":
                my_kaf.add_dependency(
                    origen=dependency[0], to=dependency[1], rfunc=dependency[2])

    def _extract_save_ner(self, line, my_kaf, term_id):
        # NER spans into KAF NEs
        ner = line[self.CONLL_COLUMN_FOR_ENTITY].replace("_", "")
        # Add the token to all open NE
        for ner_reference in self.ner_references:
            ner_reference[1].append(term_id)
        # Process all the NE tokens (if exist)
        for ner_token in ner.split("|"):
            # Create a new token reference with current term
            if ner_token.startswith("("):
                ner_type = re.sub(r"\(|\)", "", ner_token)
                self.ner_references.append((ner_type, [term_id]))
            # Close the token reference and store in KAF
            if ner.endswith(")"):
                self.eid += 1
                entity_id = 'e{0}'.format(self.eid)
                if len(self.ner_references) > 0:
                    ner_type, ner_terms = self.ner_references.pop()
                    my_kaf.add_entity(
                        eid=entity_id,
                        entity_type=ner_type,
                        references=[ner_terms])

    def _extract_coreference(self, line, term_id):
        coref = line[self.CONLL_COLUMN_FOR_COREFERENCE].replace("_", "")
        # still open
        for rolling_id in self.open_coref_references:
            for ref in self.open_coref_references[rolling_id]:
                ref.append(term_id)
        if coref:
            self.logger.debug("coref element: %s %s", coref, line)
        for coref_part in coref.split("|"):
            coref_id = coref_part.replace("(", "").replace(")", "")
            # if Is a marked word open or close the reference (or both)
            if coref_part.startswith("("):
                reference = [term_id]
                try:
                    self.open_coref_references[coref_id].append(reference)
                except KeyError:
                    self.open_coref_references[coref_id] = [reference]
                try:
                    self.coref_references[coref_id].append(reference)
                except KeyError:
                    self.coref_references[coref_id] = [reference]
            if coref_part.endswith(")"):
                try:
                    self.open_coref_references[coref_id].pop()
                    # if len(coref_references[coref_id]) == 0:
                    #   del open_coref_references[coref_id]
                except Exception as ex:
                    self.logger.exception(
                        "Problem with coref element: %s %s",
                        coref, coref_part)
                    raise ex

    def _save_coreference(self, my_kaf):
        for rolling_id in self.coref_references:
            coref_id_label = 'c{0}'.format(rolling_id)
            references = self.coref_references[rolling_id]
            self.logger.debug("%s: %s", rolling_id, references)
            my_kaf.add_coreference(coid=coref_id_label, references=references)

    def _extract_save_word(self, line, my_kaf, offset, sentence, token_index):
        word_id = 'w{0}'.format(token_index)
        word = line[self.CONLL_COLUMN_FOR_TEXT]
        # if type(word) is not unicode:
        #     word = unicode(word, "utf-8")
        word_length = len(word)
        offset += word_length + 1
        attrib = {
            "sent": str(sentence),
            "offset": str(offset),
            "length": str(word_length)}
        my_kaf.add_word(word=word, wid=word_id, **attrib)

        return word_id,  offset

    def _extract_save_term(self, line, my_kaf, token_index, words):
        term_id = 't{0}'.format(token_index)
        lemma = line[self.CONLL_COLUMN_FOR_LEMMA]
        # if type(lemma) is not unicode:
        #     lemma = unicode(lemma, "utf-8")
        pos = line[self.CONLL_COLUMN_FOR_POS]
        feat_line = line[self.CONLL_COLUMN_FOR_FEAT]
        morphofeat = "pos={0}|{1}".format(pos, feat_line)

        my_kaf.add_term(
            tid=term_id, lemma=lemma, pos=pos, morphofeat=morphofeat,
            words=words, term_type="close")
        return term_id

    def _generate_kaf(self, part, language):
        """ From a Conll part generate the kaf representation of it.

        :param part: The plain text of a Conll file part.
        :param language: The language to mark the KAF file.
        """
        my_kaf = NAFDocument(language=language)
        # Counters used in parsing
        # Document counters
        word_number = 1
        self.eid = 0
        sentence_number = 1
        offset = 0
        # Temporal entities containers
        self.ner_references = []
        self.coref_references = {}
        self.open_coref_references = {}
        # Process Lines
        sentence_words_term_id = ["ROOT", ]
        sentence_word_number = 1
        for line in part:
            if not line[0]:
                sentence_number += 1
                sentence_word_number = 1
                sentence_words_term_id = ["ROOT", ]

            else:

                word_id, offset = self._extract_save_word(
                    line, my_kaf, offset, sentence_number, word_number)

                term_id = self._extract_save_term(
                    line, my_kaf, word_number, (word_id, ))
                # list of word ordered by position(because dependencies identify
                # the words by its position)
                sentence_words_term_id.append(term_id)
                # word positions are 1 based index and they are stored in a list
                # with root as 0 element so word position - 1 is stored instead
                # of word position
                self._extract_save_ner(line, my_kaf, term_id)
                self._extract_coreference(line, term_id)
                sentence_word_number += 1
                word_number += 1
        # Write the coreference
        self.logger.debug("Found %s coreference mentions", len(self.coref_references))
        self._save_coreference(my_kaf)
        # Pretty print insert a final \n
        return my_kaf.__str__().decode(my_kaf.encoding)[:-1]

    def extract_text(self, part):
        """ Extract the text of the CONLL document part and add to tex_file

        :param part: The conll part File
        """
        text = "\n".join([line[self.CONLL_COLUMN_FOR_TEXT] for line in part]) +\
               "\n"
        return text

    @staticmethod
    def parse_cmd_arguments():
        """ Get the necessary metadata to complete the KAF."""
        parser = argparse.ArgumentParser(
            description="Process a CONLL file into a kaf one")
        parser.add_argument(
            '--file',  dest='file', action='store', default=None,
            help="File to process, if no determined used standard input.")
        parser.add_argument(
            '--language', '-lang', '-l',
            dest='language', action='store', default="en",
            help="Language of the semeval corpus")
        parser.add_argument(
            '--encoding', '-e',
            dest='encoding', action='store', default="utf-8",
            help="Encoding of the file")
        parser.add_argument(
            '--annotation', '-a',
            dest='annotation', choices=["gold", "auto"],
            default="gold",
            help="Annotation of the semeval to extract gold or auto.")
        parser.add_argument(
            '--extract_text',
            dest='extract_text',
            default=None,
            help="output extension for text files, Not extracted by default")
        parser.add_argument(
            '--output_ext',
            dest='output_extension', default="naf",
            help="Output extension for the naf files.")
        parser.add_argument(
            '--output_dir',
            dest='output_dir', default=None,
            help="Output path for the naf files.")
        parser.add_argument(
            '--dtd',
            dest='dtd', action='store', default=None,
            help="Dtd to check output NAF.")
        parser.add_argument(
            '--verbose',
            dest='verbose', action='store_true',
            help="Shoe more process info.")
        return parser.parse_args()

    def process_file(
            self, file_name,  encoding, language, output_extension, output_dir,
            text_extension=None):
        """Split the file in part extract the info and store in different naf
        files. One per part.

        :param text_extension: The extension of the plain text output.
        :param output_dir: The directory to out files.
        :param output_extension: The extension of the NAF File
        :param encoding: The encoding of the original File.
        :param language: The language of the files.
        :param file_name: The path of the Conll file.
        """
        # Create the paths
        if output_dir:
            path = output_dir
        elif file_name:
            path, full_name = os.path.split(file_name)
        else:
            self.logger.debug("No output path set.")
            raise Exception("No output path set.")

        # File Names patterns(For parts)
        text_name = os.path.join(path, "{0}." + text_extension)
        kaf_name = os.path.join(path, "{0}." + output_extension)
        coref_name = os.path.join(path, "{0}." + "coref")
        # The parts_size of a file , the speakers of each part, the tokens
        # of each part.
        if file_name:
            with codecs.open(file_name, "r", encoding=encoding) as input_file:
                parts_size, parts, names = extractor._extract_parts_form_file(
                    input_file)
        else:
            file_name = "Standard Input"
            parts_size, parts, names = extractor._extract_parts_form_file(
                io.TextIOWrapper(sys.stdin.buffer, encoding=encoding)
            )

        self.logger.info("Start processing file: {0}".format(file_name))
        # Slice the file in parts
        terms_token_start = "<terms>"
        terms_token_end = "</terms>"
        entity_token_start = "<entities>"
        entity_token_end = "</entities>"
        coreference_token_start = "<coreferences>"
        coreference_token_end = "</coreferences>"

        for index, part in enumerate(parts):
            # Write plain text of the File
            with codecs.open(text_name.format(names[index]), "w") as text_file:
                text_file.write(self.extract_text(part))

            # Write part in NAF format
            with codecs.open(coref_name.format(names[index]), "w") as coref_file:
                with codecs.open(kaf_name.format(names[index]), "w") as kaf_file:
                    kaf = self._generate_kaf(part, language.upper())

                    # terms erase
                    pre_terms, rest = kaf.split(terms_token_start)
                    terms_part, post_terms = rest.split(terms_token_end)
                    kaf = pre_terms + post_terms

                    # entity cut
                    if entity_token_start in kaf:
                        pre_entity, rest = kaf.split(entity_token_start)
                        entity_part, post_entity = \
                            rest.split(entity_token_end)
                        kaf = pre_entity + post_entity
                        coref_file.write(entity_token_start)
                        coref_file.write(entity_part)
                        coref_file.write(entity_token_end)

                    # coreference cut
                    if coreference_token_start in kaf:
                        pre_coreference, rest = kaf.split(coreference_token_start)
                        coreference_part, post_coreference = \
                            rest.split(coreference_token_end)
                        kaf = pre_coreference + post_coreference

                        coref_file.write(coreference_token_start)
                        coref_file.write(coreference_part)
                        coref_file.write(coreference_token_end)
                    
                    kaf_file.write(kaf)
                    self.logger.info(
                        "Processed part: {0}".format(names[index]))
        self.logger.info(
            "Processed{0}: {1} parts".format(file_name, len(parts_size)))


if __name__ == "__main__":
    logging.basicConfig(
        stream=sys.stderr, format='%(levelname)s - %(message)s',
        level=logging.ERROR)
    logger = logging.getLogger(__name__)
    try:
        parameters = Extractor.parse_cmd_arguments()
        if parameters.verbose:
            logger.setLevel(logging.DEBUG)
        extractor = Extractor(annotation=parameters.annotation)
        extractor.process_file(
            file_name=parameters.file, encoding=parameters.encoding,
            language=parameters.language,
            output_extension=parameters.output_extension,
            output_dir=parameters.output_dir,
            text_extension=parameters.extract_text,)
    except Exception as error:
        logger.exception("Unexpected error")
        sys.exit(-1)
