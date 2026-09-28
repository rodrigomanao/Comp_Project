# COMP Project

Compiler for a Java-like language built with **Lex/Flex + Yacc/Bison + C**.
The project evolves in 4 milestones (meta1..meta4): lexical analysis, parsing/AST, semantic analysis, and LLVM code generation.

## Authors
- David Pedrosa (2021275573)
- Rodrigo Manão (2023207589)

## Requirements
- `make`
- `lex`/`flex`
- `bison`
- C compiler (`cc`)
- `lli` (LLVM interpreter, required to run meta4 tests)

## Build
```bash
cd /home/runner/work/Comp_Project/Comp_Project
make
```

Generated executable: `./jucompiler`

## Compiler modes
Run with input from stdin:

```bash
./jucompiler [flag] < file.java
```

Flags:
- `-l`   lexical output (tokens + lexical errors)
- `-e1`  lexical/syntax errors mode
- `-e2`  syntax errors mode used in meta2 tests
- `-t`   print AST
- `-s`   print symbol tables + annotated AST
- `-e3`  semantic errors mode
- no flag: semantic analysis + LLVM IR generation (meta4)

## Useful Make targets
- Build: `make`
- Clean generated files: `make clean`
- Run one file (default `FLAG=-e2`):
  ```bash
  make run FILE=meta2/Factorial FLAG=-e2
  ```
- Diff output against expected `.out`:
  ```bash
  make diff FILE=meta2/Factorial FLAG=-e2
  ```
- Auto-locate file across `meta1..meta4` and run:
  ```bash
  make f FILE=Factorial FLAG=-e2
  ```
- Auto-locate file and diff:
  ```bash
  make fdiff FILE=Factorial FLAG=-e2
  ```

## Test scripts
### Run full milestone suites
```bash
./test.sh ./jucompiler
```

Run only one milestone:
```bash
./test.sh ./jucompiler 1   # meta1
./test.sh ./jucompiler 2   # meta2
./test.sh ./jucompiler 3   # meta3
./test.sh ./jucompiler 4   # meta4 (requires lli)
```

### Alternative directory-based script
```bash
./test2.sh -e2 meta2
./test2.sh -t meta2
```

## Repository layout
- `jucompiler.l` / `jucompiler.y` — lexer and parser
- `ast.*` — AST structures and utilities
- `semantics.*` — semantic analysis and symbol tables
- `codegen.*` — LLVM IR generation
- `meta1..meta4/` — test inputs and expected outputs
