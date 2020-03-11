for metric in ceafe ceafm muc bcub blanc
do
   echo $metric
   perl scorer.pl $metric $1  $2  > temp
   tail temp -n 3 
done
