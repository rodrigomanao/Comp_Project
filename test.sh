# examples:
# ./test.sh -l meta1
# ./test.sh -t meta2
for i in $2/*.java; do
    ./main $1 < "$i" | diff -u --color "${i/%.java}.out" -;
done
