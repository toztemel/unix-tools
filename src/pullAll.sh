#!/bin/bash

for REPO in `ls`; do (cd "$REPO"; git pull --rebase); done;

