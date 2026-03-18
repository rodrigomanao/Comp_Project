# Makefile for jucompiler
COMPILER = jucompiler
LEX_FILE = jucompiler.l
CC = cc
LFLAGS = -ll

.PHONY: all clean run test diff

# Build: lex + compile
all: $(COMPILER)

$(COMPILER): $(LEX_FILE)
	lex $(LEX_FILE)
	$(CC) lex.yy.c -o $(COMPILER) $(LFLAGS)

# Run test suite: make test
test: $(COMPILER)
	./test.sh -l meta1

# Run on a specific file: make run FILE=factorial
# Prints tokens to stdout
run: $(COMPILER)
ifndef FILE
	$(error Use: make run FILE=<nome do ficheiro sem extensão>)
endif
	./$(COMPILER) -l < $(FILE).in

# Diff against expected output: make diff FILE=factorial
diff: $(COMPILER)
ifndef FILE
	$(error Use: make diff FILE=<nome do ficheiro sem extensão>)
endif
	./$(COMPILER) -l < $(FILE).in | diff $(FILE).out -

clean:
	rm -f lex.yy.c $(COMPILER)