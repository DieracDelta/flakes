#!/usr/bin/env bash

export SOPS_PGP_FP="$(cat desktop.private),$(cat laptop.private),$(cat laptop_global.private)"
