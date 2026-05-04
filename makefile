# Makefile for jucompiler 
COMPILER = jucompiler
LEX_FILE = jucompiler.l
YACC_FILE = jucompiler.y
AST_FILE = ast.c
SEMANTICS_FILE = semantics.c
CC = cc
BISON ?= /opt/homebrew/opt/bison/bin/bison

.PHONY: all clean run diff f fdiff

# Build: yacc + lex + compile
all: $(COMPILER)

$(COMPILER): $(LEX_FILE) $(YACC_FILE) $(AST_FILE) $(SEMANTICS_FILE)
	$(BISON) -d -v -y -o y.tab.c $(YACC_FILE)
	lex $(LEX_FILE)
	$(CC) y.tab.c lex.yy.c $(AST_FILE) $(SEMANTICS_FILE) -o $(COMPILER)

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

# Shorthand run for a single file:
#   make f FILE=meta2/Factorial FLAG=-e2
#   make f FILE=Factorial FLAG=-e2          (tries ./Factorial.java, meta2/Factorial.java, meta1/Factorial.java)
f: $(COMPILER)
ifndef FILE
	$(error Use: make f FILE=<path ou nome base> [FLAG=-e2])
endif
	@src='$(FILE)'; \
	case "$$src" in *.java) ;; *) src="$$src.java" ;; esac; \
	if [ ! -f "$$src" ] && [ -f "meta2/$$src" ]; then src="meta2/$$src"; fi; \
	if [ ! -f "$$src" ] && [ -f "meta1/$$src" ]; then src="meta1/$$src"; fi; \
	if [ ! -f "$$src" ]; then echo "File not found: $$src"; exit 2; fi; \
	./$(COMPILER) $(FLAG) < "$$src"

# Shorthand diff for a single file:
#   make fdiff FILE=meta2/Factorial FLAG=-t
fdiff: $(COMPILER)
ifndef FILE
	$(error Use: make fdiff FILE=<path ou nome base> [FLAG=-e2])
endif
	@src='$(FILE)'; \
	case "$$src" in *.java) ;; *) src="$$src.java" ;; esac; \
	if [ ! -f "$$src" ] && [ -f "meta2/$$src" ]; then src="meta2/$$src"; fi; \
	if [ ! -f "$$src" ] && [ -f "meta1/$$src" ]; then src="meta1/$$src"; fi; \
	if [ ! -f "$$src" ]; then echo "File not found: $$src"; exit 2; fi; \
	base="$${src%.java}"; expected="$$base.out"; \
	if [ ! -f "$$expected" ]; then echo "Expected output not found: $$expected"; exit 2; fi; \
	./$(COMPILER) $(FLAG) < "$$src" | diff -u --color=always "$$expected" -