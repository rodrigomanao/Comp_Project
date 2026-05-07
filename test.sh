#!/usr/bin/env bash

if [[ -z "$1" ]]; then
  echo "Usage: $0 <executable> [meta_number]"
  echo "Example: $0 ./jucompiler 4"
  exit 1
fi

exe="$1"
target_meta="$2" # Opcional: 1, 2, 3 ou 4

accepted=0
total=0

# Função auxiliar para correr testes de uma meta
run_meta_tests() {
  local meta_num=$1
  local flag=$2
  local folder="meta$meta_num"

  if [[ -d "$folder" ]]; then
    echo "--- Running Meta $meta_num ---"
    for inp in "$folder"/*.java; do
      total=$(($total + 1))
      out=${inp%.java}.out
      tmp=${inp%.java}.out_temp
      
      # Ajuste de flags específicas por ficheiro (ex: _e1, _e2)
      current_flag="$flag"
      if [[ "$inp" == *"_e$meta_num.java" ]]; then
        current_flag="-e$meta_num"
      fi

      # Lógica especial para a Meta 4 (LLVM)
      if [[ "$meta_num" -eq 4 ]]; then
        tmp_ll=${inp%.java}.ll
        in_file=${inp%.java}.in
        
        if $exe $current_flag <"$inp" >"$tmp_ll" 2>/dev/null; then
          if ! grep -q "define.*@main" "$tmp_ll"; then
            touch "$tmp"
          else
            args=""
            [[ -f "$in_file" ]] && args=$(cat "$in_file")
            lli "$tmp_ll" $args >"$tmp" 2>/dev/null
          fi
        else
          echo "  $inp: Compilation Error" && continue
        fi
      else
        # Lógica para Metas 1, 2 e 3
        $exe $current_flag <"$inp" >"$tmp" 2>/dev/null
      fi

      # Comparação de resultados (ignora espaços em branco com -w)
      if diff -w "$out" "$tmp" >/dev/null; then
        echo "  [OK] $inp"
        accepted=$(($accepted + 1))
      else
        echo "  [FAIL] $inp (diff $out $tmp)"
      fi
    done
  fi
}

# Execução baseada no argumento
if [[ -n "$target_meta" ]]; then
    # Se especificaste uma meta, corre apenas essa
    case "$target_meta" in
        1) run_meta_tests 1 "-l" ;;
        2) run_meta_tests 2 "-t" ;;
        3) run_meta_tests 3 "-s" ;;
        4) run_meta_tests 4 ""   ;;
        *) echo "Meta $target_meta unknown." ;;
    esac
else
    # Se não especificaste, corre todas
    run_meta_tests 1 "-l"
    run_meta_tests 2 "-t"
    run_meta_tests 3 "-s"
    run_meta_tests 4 ""
fi

echo "----------------------------"
echo "Final Result: $accepted / $total"