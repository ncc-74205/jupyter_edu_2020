#!/bin/bash
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

mysqld_safe --skip-grant-tables &

tini -g -- "$@"
