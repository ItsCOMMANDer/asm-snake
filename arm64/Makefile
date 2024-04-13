all:
        as main.s -o main.o
        ld main.o -o main

debug:
        as -o debug.o main.s -g
        ld -o debug debug.o -g

clean:
        rm debug debug.o main main.o