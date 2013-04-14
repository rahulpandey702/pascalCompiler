OS used for development: CIMS Solaris Machine (SunOS access1 5.10 Generic_142900-15 sun4v sparc SUNW)
(Code should run on any Linux/CIMS SUN machine with gcc installed)
Tested on: CIMS machine
Compiler used: gcc (VERSION: 4.5.0 )

The lexical specification is included in file lex.l and production rules in syntax.y.

How to Compile?
Simply run the following command:
1 flex lex.l
2 bison -d syntax.y
2 gcc -g syntax.tab.c lex.yy.c stack.c -ll -o lab4

How to Run?
To run the code, enter the following command on terminal:
3 ./lab4 < (input file)
