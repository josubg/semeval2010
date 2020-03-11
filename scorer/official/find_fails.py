#! /usr/bin/python
# coding: utf-8

res_file = open('res.index', 'r').readlines()
key_file = open('key.index', 'r').readlines()
found = []
fail = []
for line in res_file:
    if line in key_file:
        found.append(line)
    else:
        fail.append(line)
fail_mentions = "".join(fail)

print "fails:\n {2}\nGold: {0}\nRes: {1}\n Fails {3}".format(len(key_file),len(res_file), fail_mentions, len(fail))
