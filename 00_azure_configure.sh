#!/usr/bin/env bash
set -euo pipefail

# If TENANT is not set or is empty, prompt for it or allow interactive login
if [ -z "${TENANT:-}" ]; then
  echo "TENANT environment variable is not set."
  read -r -p "Enter Azure tenant id (leave empty to run 'az login' interactively): " tenant_input

  if [ -n "$tenant_input" ]; then
    TENANT="$tenant_input"
  else
    echo "Running 'az login' interactively..."
    az login
    exit 0
  fi
fi

echo "Logging in to tenant: $TENANT"
az login --tenant "$TENANT"
echo "Login successful."


