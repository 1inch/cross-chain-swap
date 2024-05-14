#!/bin/bash

printf "Running forge snapshot --diff... \n"
if forge snapshot --diff | grep -q "Overall gas change: 0 (0.000%)";
then
  printf "${GREEN}No gas difference${NC} \n"
else
  printf "${RED}Gas difference${NC} Please run forge snapshot and add changes to the commit. \n"
  exit 1
fi
