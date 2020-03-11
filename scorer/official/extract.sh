
cat ./buff.key.conll.$1   |nl -b a| sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" | sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" |  egrep "\)[[:space:]]*$" | awk  '{ print $1}' > key.index

cat ./buff.res.conll.$1 |nl -b a| sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" | sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" | sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" | sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" | sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" | sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" | sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" | sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" | sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" | sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" | sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" | sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" | sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" | sed -r "s:^(.+) (\(?[[:alnum:]]+\)?)\|(.+):\1 \2\n\1 \3:" |  egrep "\)[[:space:]]*$" | uniq | awk  '{ print $1}' > res.index

python find_lost.py > losts.txt
python find_fails.py > fails.txt
