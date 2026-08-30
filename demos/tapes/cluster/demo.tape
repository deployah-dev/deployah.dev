# Local well: cluster up, then cluster status.
# Render with: nix run .#demo
# Requires Docker or Podman.
#
# Hide pulls the Kind node image (up, then down --force) so the filmed
# up creates a cluster. Do not deploy. Status should show Ready and the
# cloud provider. Clear after up. Uses demos/nginx.
Output demos/out/cluster.mp4

Require deployah
Require zsh
Require starship

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
Type "deployah cluster down --force"
Enter
Wait /λ/
Type `export COLUMNS=80`
Enter
Wait /λ/
Type "clear"
Enter
Sleep 300ms
Show

Type "deployah cluster up"
Enter
Wait /λ/
Sleep 2s
Hide
Type "clear"
Enter
Wait /λ/
Show

Type "deployah cluster status"
Enter
Wait /λ/
Sleep 4s
