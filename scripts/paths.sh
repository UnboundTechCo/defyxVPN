#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

GLOBAL_VARS_FILE="${PROJECT_ROOT}/lib/shared/global_vars.dart"
PUBSPEC_FILE="${PROJECT_ROOT}/pubspec.yaml"
ENV_FILE="${PROJECT_ROOT}/.env"
