#!/bin/bash

# Recebe a flag e a diretoria dos argumentos
FLAG=$1
DIR=$2

if [ -z "$FLAG" ] || [ -z "$DIR" ]; then
    echo "Uso: ./test.sh <flag> <diretorio>"
    echo "Exemplo 1 (Erros de Sintaxe): ./test.sh -e2 testes_meta2"
    echo "Exemplo 2 (Imprimir AST):     ./test.sh -t testes_meta2"
    exit 1
fi

echo "A compilar o compilador..."
make clean > /dev/null
make > /dev/null
if [ $? -ne 0 ]; then
    echo "❌ Erro ao compilar. Corrige os erros no código C/Yacc/Lex primeiro."
    exit 1
fi

echo "A testar ficheiros no diretório '$DIR' com a flag '$FLAG'..."
echo "---------------------------------------------------"

PASSED=0
FAILED=0

# Percorre todos os ficheiros .java na diretoria escolhida
for file in "$DIR"/*.java; do
    # Ignora se não existirem ficheiros java
    [ -e "$file" ] || continue
    
    base="${file%.java}"
    expected="${base}.out"

    if [ ! -f "$expected" ]; then
        echo "⚠️  Aviso: Ficheiro esperado ($expected) não encontrado para $file"
        continue
    fi

    # Corre o programa e guarda a diferença
    diff_result=$(./jucompiler "$FLAG" < "$file" | diff -u --color "$expected" -)

    if [ $? -eq 0 ]; then
        echo "✅ PASSED: $file"
        ((PASSED++))
    else
        echo "❌ FAILED: $file"
        echo "$diff_result"
        echo "---------------------------------------------------"
        ((FAILED++))
    fi
done

echo ""
echo "Resumo: $PASSED Passaram | $FAILED Falharam"

#exemplos
#./test.sh -e2 meta2 erros de sintaxe
#./test.sh -t meta2 para a arvore
#make diff FILE=meta2/Factorial FLAG=-e2 para um ficheiro em especifico
