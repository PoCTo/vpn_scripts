#!/usr/bin/python3

from random import randint

with open('/usr/share/dict/american-english', 'r') as f:
  l = f.readlines()
  selected = []
  while len(selected) != 2:
    rand = randint(0, len(l) - 1)
    if l[rand].strip().isalpha() and 3 <=len(l[rand].strip()) <= 6:
      selected.append(l[rand].strip().lower())

print('-'.join(selected))
