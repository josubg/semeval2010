#!/usr/bin/env bash
#for metric in  ceafm muc bcub blanc
#do
#   rm ${metric}  2> /dev/null
#done

perl ./scorer/v8.01/scorer.pl muc $1  $2  > MD
tail -n4 MD | head -n1 | awk '{ORS=", ";OFS=", "}{print $8, $13, $15}'|  tr -d %
for metric in  ceafm muc bcub blanc
do
   perl ./scorer/v8.01/scorer.pl ${metric} $1  $2  > ${metric}
   tail -n2 ${metric} | head -n1 | awk '{ORS=", ";OFS=", "}{print $6, $11, $13}'|  tr -d %
done

#for metric in  ceafm muc bcub blanc
#do
#   rm ${metric}  2> /dev/null
#done