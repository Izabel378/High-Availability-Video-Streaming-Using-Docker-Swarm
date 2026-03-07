#!/bin/bash

pgrep dockerd > /dev/null 2>&1
exit $?
