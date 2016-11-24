#!/bin/bash

cat gem_list | while read gem
do

	OLD_IFS="$IFS" 
	IFS=" " 
	arr=($gem) 
	IFS="$OLD_IFS" 
	gemName=${arr[0]}
	gemVersion=${arr[1]}
	cmd="sudo gem install $gemName -v '$gemVersion'"
	echo $cmd
	sleep 8
done
