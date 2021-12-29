#!/bin/bash

branchName=$1

echo -----------------
git status

if [ "$branchName" == "" ]; then
    echo -----------------
    git branch
    read -p "enter branch name and press ENTER: " branchName
fi
git checkout $branchName
