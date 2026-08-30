# Demos

VHS tapes for the landing and the CLI README. Output is flat under
`demos/out/` (gitignored). Vite serves `/demos/<file>` and rejects slashes
in the name. Publish to `https://deployah.dev/demos/`.

Hero tapes (`Source _hero.tape`, 1920x1080) get captions, Vastness mixed
under the clip (1s in, 2s out), a 1400x700 GIF, and a Chromium concat if
`browser.yaml` exists. Well tapes (`_well.tape`,
960x540) write the mp4 and a JPEG poster. Logs and shell use project
`app` so they do not overwrite the nginx hero release. `nix run .#demo`
renders every `demo.tape`, wells first. Shared `_*.tape` files are
sourced only.

## Render and publish

Docker or Podman. From the repo root:

```sh
nix run .#demo
nix develop .#demo   # iterate; exports STARSHIP_* and ZSH_SYNTAX_HIGHLIGHTING
```

A hero with `browser.yaml` starts the cluster, records VHS, deploys on
the host, then records Chromium on the first Ingress URL from
`deployah cluster status`. Caption times are seconds from on-camera VHS
(`Hide` omitted). `browser_captions` are from the Chromium shot; the app
adds the VHS duration so they do not overlap.

```sh
export R2_ACCESS_KEY_ID=...
export R2_SECRET_ACCESS_KEY=...
export R2_ENDPOINT_URL=...
export R2_BUCKET=deployah
export R2_DEST_PATH=demos/
nix run .#publish-demo
```

`*-vhs.mp4` is not uploaded. Landing: `/demos/nginx-captioned.mp4`,
`nginx.jpg`, `cluster.mp4`, `plan.mp4`, `logs.mp4`, `shell.mp4`. CLI
README uses `https://deployah.dev/demos/nginx.gif`.

## New tape

1. Fixture in `demos/<name>/`, or `cd` into one (e.g. `demos/nginx`).
2. `demos/tapes/<name>/demo.tape`: `Output demos/out/<name>.mp4`, then
   `Source` `_common.tape`, `_hero.tape` or `_well.tape`, `_zsh.tape`.
   Wait with `Wait /λ/`.
3. Hero only: `captions.yaml`, optional `browser.yaml` (`duration` seconds).
4. `nix run .#demo` and `nix run .#publish-demo`.
