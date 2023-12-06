pansel: pansel.cpp
	g++ -fsanitize=address -g -Wall -Wpedantic -O3 -o pansel pansel.cpp

clean:
	\rm pansel
