#!/bin/bash

source ./test.conf

func()
{
    if [ -n "$stuff" ]
    then ret=0
    else ret=1
    fi
}

for i in ${test[*]}
do
    echo "$i"
done

echo "loop 2:"
len=`expr ${#test[@]} - 1`
for i in $(seq 0 1 $len)
do
    echo "${test[$i]}"
done
stuff="stuff"
func
if [ $ret -eq 0 ]
then echo "func"
else echo "nofunc"
fi
echo | date +%Y-%m-%d-%H
