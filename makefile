# Makefile for jucompiler 
COMPILER = jucompiler
LEX_FILE = jucompiler.l
YACC_FILE = jucompiler.y
AST_FILE = ast.c
CC = cc

.PHONY: all clean run diff

# Build: yacc + lex + compile
all: $(COMPILER)

$(COMPILER): $(LEX_FILE) $(YACC_FILE) $(AST_FILE)
	yacc -d -v $(YACC_FILE)
	lex $(LEX_FILE)
	$(CC) y.tab.c lex.yy.c $(AST_FILE) -o $(COMPILER)

# Limpa todos os ficheiros gerados
clean:
	rm -f lex.yy.c y.tab.c y.tab.h y.output $(COMPILER)

# Variável padrão = -e2
FLAG ?= -e2

# Run on a specific file: make run FILE=testes_david FLAG=-t
run: $(COMPILER)
ifndef FILE
	$(error Use: make run FILE=<nome do ficheiro sem extensão>)
endif
	./$(COMPILER) $(FLAG) < $(FILE).java

# Diff against expected output: make diff FILE=testes_david FLAG=-t
diff: $(COMPILER)
ifndef FILE
	$(error Use: make diff FILE=<nome do ficheiro sem extensão>)
endif
	./$(COMPILER) $(FLAG) < $(FILE).java | diff -u --color $(FILE).out -