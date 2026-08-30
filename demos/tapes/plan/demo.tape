# Plan well: first-install (4 to add), then a resources change (1 to change).
# Render with: nix run .#demo
# Requires Docker or Podman.
#
# Use an online plan. --offline never diffs the cluster, so it cannot
# show "4 to add". Delete first. Deploy off camera. Nano inserts
# resources (cpu: 100m, memory: 128Mi). Do not Wait /λ/ while nano is
# open. Explicit resources skip the small preset, so omitting
# ephemeralStorage drops the default 50Mi. Restore the spec off camera.
# Uses demos/nginx.
Output demos/out/plan.mp4

Require deployah
Require zsh
Require starship
Require nano

Source demos/tapes/_common.tape
Source demos/tapes/_well.tape
Source demos/tapes/_zsh.tape

Hide
Type "cd demos/nginx"
Enter
Sleep 300ms
Type "deployah cluster up"
Enter
Wait /λ/
Type "deployah delete nginx local --yes >/dev/null 2>&1 || true"
Enter
Wait /λ/
Type `export COLUMNS=80`
Enter
Wait /λ/
Type "clear"
Enter
Sleep 300ms
Show

Type "deployah plan local"
Enter
Wait /λ/
Sleep 4s
Hide
Type "deployah deploy local --yes"
Enter
Wait /λ/
Type "clear"
Enter
Wait /λ/
Show

Type "nano +6 deployah.yaml"
Enter
Sleep 800ms
Ctrl+E
Enter
Type "    resources:"
Enter
Type "      cpu: 100m"
Enter
Type "      memory: 128Mi"
Sleep 3s
Ctrl+O
Enter
Sleep 400ms
Ctrl+X
Wait /λ/
Sleep 2s
Hide
Type "clear"
Enter
Wait /λ/
Show

Type "deployah plan local --yaml"
Enter
Wait /λ/
Sleep 16s
Hide
Type `printf '%s\n' 'apiVersion: v1-alpha.5' 'project: nginx' 'components:' '  web:' '    image: nginx:1.26' '    port: 80' '    environments: [local]' '    expose: true' > deployah.yaml`
Enter
Wait /λ/
