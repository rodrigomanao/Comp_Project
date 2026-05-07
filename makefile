# Nome do executável
COMPILER = jucompiler
LEX_FILE = jucompiler.l
YACC_FILE = jucompiler.y

# Lista de ficheiros C (incluindo o novo codegen.c)
SRCS = ast.c semantics.c codegen.c
CC = cc

# DETEÇÃO DO SISTEMA OPERATIVO
OS := $(shell uname -s)

ifeq ($(OS), Darwin)
    # Se for Mac (colega), usa o caminho do Homebrew
    BISON = /opt/homebrew/opt/bison/bin/bison
else
    # Se for Windows (WSL) ou Linux (DEI), usa o bison do sistema
    BISON = bison
endif

.PHONY: all clean run diff f fdiff

# Build: yacc + lex + compile
all: $(COMPILER)

$(COMPILER): $(LEX_FILE) $(YACC_FILE) $(SRCS)
	$(BISON) -d -v -y -o y.tab.c $(YACC_FILE)
	lex $(LEX_FILE)
	$(CC) y.tab.c lex.yy.c $(SRCS) -o $(COMPILER)

# Limpa todos os ficheiros gerados
clean:
	rm -f lex.yy.c y.tab.c y.tab.h y.output $(COMPILER)

# Variável padrão para flags (Meta 2 = -e2, Meta 4 costuma ser vazio ou flag específica)
FLAG ?= -e2

# Run e Diff (Geral)
run: $(COMPILER)
ifndef FILE
	$(error Use: make run FILE=<nome do ficheiro sem extensão>)
endif
	./$(COMPILER) $(FLAG) < $(FILE).java

diff: $(COMPILER)
ifndef FILE
	$(error Use: make diff FILE=<nome do ficheiro sem extensão>)
endif
	./$(COMPILER) $(FLAG) < $(FILE).java | diff -u --color $(FILE).out -

# Shorthands para facilitar os testes (procura nas pastas meta1, meta2, etc)
f: $(COMPILER)
ifndef FILE
	$(error Use: make f FILE=<path ou nome base> [FLAG=-e2])
endif
	@src='$(FILE)'; \
	case "$$src" in *.java) ;; *) src="$$src.java" ;; esac; \
	if [ ! -f "$$src" ] && [ -f "meta4/$$src" ]; then src="meta4/$$src"; fi; \
	if [ ! -f "$$src" ] && [ -f "meta3/$$src" ]; then src="meta3/$$src"; fi; \
	if [ ! -f "$$src" ] && [ -f "meta2/$$src" ]; then src="meta2/$$src"; fi; \
	if [ ! -f "$$src" ] && [ -f "meta1/$$src" ]; then src="meta1/$$src"; fi; \
	if [ ! -f "$$src" ]; then echo "File not found: $$src"; exit 2; fi; \
	./$(COMPILER) $(FLAG) < "$$src"

fdiff: $(COMPILER)
ifndef FILE
	$(error Use: make fdiff FILE=<path ou nome base> [FLAG=-e2])
endif
	@src='$(FILE)'; \
	case "$$src" in *.java) ;; *) src="$$src.java" ;; esac; \
	if [ ! -f "$$src" ] && [ -f "meta4/$$src" ]; then src="meta4/$$src"; fi; \
	if [ ! -f "$$src" ] && [ -f "meta3/$$src" ]; then src="meta3/$$src"; fi; \
	if [ ! -f "$$src" ] && [ -f "meta2/$$src" ]; then src="meta2/$$src"; fi; \
	if [ ! -f "$$src" ] && [ -f "meta1/$$src" ]; then src="meta1/$$src"; fi; \
	if [ ! -f "$$src" ]; then echo "File not found: $$src"; exit 2; fi; \
	base="$${src%.java}"; expected="$$base.out"; \
	if [ ! -f "$$expected" ]; then echo "Expected output not found: $$expected"; exit 2; fi; \
	./$(COMPILER) $(FLAG) < "$$src" | diff -u --color=always "$$expected" -