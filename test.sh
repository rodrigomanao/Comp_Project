#!/usr/bin/env bash
#
#  Utilização
#    bash test.sh ./path/to/jucompiler
#
#  Funcionalidade
#  Compara todos os casos de teste na pasta meta1, meta2, meta3 e meta4
#  Cria o ficheiro *casoteste*.out_temp com resultado de correr cada caso de teste

if [[ -z "$1" ]]; then
  echo "Missing argument executable"
  echo "Usage: $0 executable"
  echo "Example: $0 ./path/to/jucompiler"
  exit 1
fi

exe="$1"

accepted=0
total=0

if [[ -d meta1 ]]; then
  for inp in meta1/*.java; do
    total=$(($total + 1))
    echo "$inp"
    out=${inp%.java}.out
    tmp=${inp%.java}.out_temp
    flag="-l"
    if [[ "$inp" == *_e1.java ]]; then
      flag="-e1"
    fi
    if $exe $flag <"$inp" >"$tmp"; then
      lines=$(diff $out $tmp | wc -l)
      if [[ $lines -gt 0 ]]; then
        echo " Wrong Answer, run 'diff $out $tmp' to see the differences"
      else
        accepted=$(($accepted + 1))
      fi
    else
      echo " Runtime Error, failed to execute '$exe'"
    fi
  done
fi

if [[ -d meta2 ]]; then
  for inp in meta2/*.java; do
    total=$(($total + 1))
    echo "$inp"
    out=${inp%.java}.out
    tmp=${inp%.java}.out_temp
    flag="-t"
    if [[ "$inp" == *_e2.java ]]; then
      flag="-e2"
    fi
    if $exe $flag <"$inp" >"$tmp"; then
      lines=$(diff $out $tmp | wc -l)
      if [[ $lines -gt 0 ]]; then
        echo " Wrong Answer, run 'diff $out $tmp' to see the differences"
      else
        accepted=$(($accepted + 1))
      fi
    else
      echo " Runtime Error, failed to execute '$exe'"
    fi
  done
fi

if [[ -d meta3 ]]; then
  for inp in meta3/*.java; do
    total=$(($total + 1))
    echo "$inp"
    out=${inp%.java}.out
    tmp=${inp%.java}.out_temp
    flag="-s"
    if [[ "$inp" == *_e3.java ]]; then
      flag="-e3"
    fi
    if $exe $flag <"$inp" >"$tmp"; then
      lines=$(diff $out $tmp | wc -l)
      if [[ $lines -gt 0 ]]; then
        echo " Wrong Answer, run 'diff $out $tmp' to see the differences"
      else
        accepted=$(($accepted + 1))
      fi
    else
      echo " Runtime Error, failed to execute '$exe'"
    fi
  done
fi

if [[ -d meta4 ]]; then
  for inp in meta4/*.java; do
    total=$(($total + 1))
    echo "$inp"
    out=${inp%.java}.out
    tmp_ll=${inp%.java}.ll
    tmp=${inp%.java}.out_temp
    in_file=${inp%.java}.in
    flag=""
    if $exe $flag <"$inp" >"$tmp_ll"; then
      if ! grep -q "define.*@main" "$tmp_ll"; then
        touch "$tmp"
      else
        args=""
        if [[ -f "$in_file" ]]; then
          args=$(cat "$in_file")
        fi
        if lli "$tmp_ll" $args >"$tmp"; then
          :
        else
          echo " Execution Error, failed to run 'lli $tmp_ll $args'"
        fi
      fi
      lines=$(diff "$out" "$tmp" | wc -l)
      if [[ $lines -gt 0 ]]; then
        echo " Wrong Answer, run 'diff $out $tmp' to see the differences"
      else
        accepted=$(($accepted + 1))
      fi
    else
      echo " Compilation Error, failed to execute '$exe'"
    fi
  done
fi

echo "Accepted: $accepted / $total"
