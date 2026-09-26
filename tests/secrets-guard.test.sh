#!/usr/bin/env bash
# Tests hooks/secrets-guard.sh: secret paths on file tools (including the
# NotebookEdit path that file permission checks don't consult), secret reads
# via Bash, and the ordinary commands that must not be caught.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/hooks/secrets-guard.sh"
FAILED=0

verdict_of() { # <json>
  if bash "$HOOK" <<<"$1" 2>&1 | grep -q '"deny"'; then echo deny; else echo allow; fi
}

check() { # <deny|allow> <label> <json>
  local expect="$1" label="$2" got
  got="$(verdict_of "$3")"
  if [ "$got" = "$expect" ]; then
    printf 'ok   %-5s %s\n' "$got" "$label"
  else
    printf 'FAIL want=%-5s got=%-5s %s\n' "$expect" "$got" "$label"
    FAILED=1
  fi
}

file_tool() { # <deny|allow> <tool> <path>
  check "$1" "$2 $3" "$(jq -n --arg t "$2" --arg p "$3" '{tool_name:$t,tool_input:{file_path:$p}}')"
}

notebook() { # <deny|allow> <path>
  check "$1" "NotebookEdit $2" "$(jq -n --arg p "$2" '{tool_name:"NotebookEdit",tool_input:{notebook_path:$p}}')"
}

bash_cmd() { # <deny|allow> <command>
  check "$1" "Bash $2" "$(jq -n --arg c "$2" '{tool_name:"Bash",tool_input:{command:$c}}')"
}

echo "# denied: secret paths through file tools"
file_tool deny  Read  /srv/app/.env
file_tool deny  Read  .env.production
file_tool deny  Edit  /home/u/certs/server.pem
file_tool deny  Write /home/u/.ssh/id_ed25519
file_tool deny  Read  /home/u/.aws/credentials
file_tool deny  Read  gcp-service-account-prod.json
file_tool deny  Read  /home/u/.npmrc

echo "# denied: NotebookEdit, which file permission rules don't cover"
notebook deny "/work/secrets/.env"

echo "# denied: reading a secret through the shell"
bash_cmd deny 'cat .env'
bash_cmd deny 'head -5 /srv/app/.env.production'
bash_cmd deny 'base64 ~/.ssh/id_rsa'
bash_cmd deny 'jq . service-account.json'
bash_cmd deny 'source .env && npm start'

echo "# allowed: ordinary paths"
file_tool allow Read  src/index.ts
file_tool allow Edit  README.md
file_tool allow Read  environment.ts
file_tool allow Read  keyboard.ts

echo "# allowed: shell commands that only mention secrets, or touch none"
bash_cmd allow 'echo "add .env to .gitignore"'
bash_cmd allow 'git add .gitignore'
bash_cmd allow 'npm test'
bash_cmd allow 'cat README.md'
bash_cmd allow 'ls -la'

exit "$FAILED"
