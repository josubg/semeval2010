#!/usr/bin/env python3

from os import walk
from os.path import join

path = "./original_task"
ext = ".txt"

for path, dirs, files in walk(path):
    for f in files:
        if f.endswith(ext):
            name = join(path, f)
            print("Processing: " + name)
            with open(name, "r") as indoc:
                with open(name+".conll", 'w') as outdoc:
                    for line in indoc:
                        if line != "\n":
                            if line.startswith("#begin"):
                                doc = line.split(" ")[-1][:-1].split(".")[0]
                                line = "#begin document ({0}); part 000\n".format(doc)
                            elif line.startswith("#end"):
                                doc = line.split(" ")[-1][:-1].split(".")[0]
                                line = "#end document\n".format(doc)
                            else:
                                tokens = line.split()
                                line = "{0}\t0\t{1}\t{2}\n".format(doc, int(tokens[0])-1, tokens[1].replace("_", "-"))
                        outdoc.write(line)
print("Done!")

