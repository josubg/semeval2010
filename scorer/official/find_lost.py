#! /usr/bin/python
# coding: utf-8

res_file = open('res.index', 'r').readlines()
key_file = open('key.index', 'r').readlines()
found = []
lost = []
for line in key_file:
    if line in res_file:
        found.append(line)
    else:
        lost.append(line)
index = 0 
lost_mentions = []
for mention in lost:
    if index == 15:
        index = 0
        lost_mentions.append("\n")
    index += 1
    lost_mentions.append(mention[:-1])

l_mentions = " ".join(lost_mentions)

print "lost:\n {2}\nGold: {0}\nRes: {1}\n Lost {3}".format(len(key_file),len(res_file), l_mentions, len(lost))
