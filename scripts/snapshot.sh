#!/bin/bash

printf "Running forge snapshot --diff... \n"
snapshot_diff="$(forge snapshot --diff)"
echo "${snapshot_diff}"
if echo "${snapshot_diff}" | grep -q "Overall gas change: 0 (0.000%)";
then
  printf "${GREEN}No gas difference${NC} \n"
else
  printf "${RED}Gas difference${NC} Please run forge snapshot and add changes to the commit. \n"
  exit 1
fi
