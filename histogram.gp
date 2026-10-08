# Ejecutar: gnuplot -c histogram.gp ruta/al/regression.csv
# Este script lee el CSV para Excel generado por regression.sh
set terminal pngcairo size 1100,650
set output "histogram.png"
set datafile separator ";"
set title "Latencia de las entregas recibidas"
set xlabel "Latencia POP -> PUSH (ns)"
set ylabel "Cantidad de entregas"
set grid ytics
set yrange [0:*]
set xrange [0:*]
set style fill solid 0.8
set boxwidth 90
unset key

width = 100
bin(x) = width * floor(x / width) + width / 2

# Excel usa coma decimal -- GNUplot necesita punto para convertir el texto.
decimal(s) = strstrt(s, ",") > 0 ? real(s[1:strstrt(s,",")-1].".".s[strstrt(s,",")+1:*]) : real(s)

plot ARGV[1] using (strcol(11) eq "received" ? bin(decimal(strcol(9))) : 1/0):(1) smooth frequency with boxes
unset output
