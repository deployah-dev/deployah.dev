# deployah.dev

Worker for [deployah.dev](https://deployah.dev): landing page, Go vanity
import, demo movies, and JSON Schemas.

## What it serves

| Path | Source | Purpose |
| --- | --- | --- |
| `/` and static files | Vite `dist/` | Landing, `og.png`, CSS, JS, `sitemap.xml`, `llms.txt` |
| `/?go-get=1` | Worker HTML | Vanity import for `deployah.dev/deployah` |
| `/demos/*` | R2 `deployah` (`MEDIA`) | Movies (e.g. `/demos/nginx.gif`) |
| `/schemas/*` | R2 `deployah` (`MEDIA`) | JSON Schemas (path matches `$id`) |
| everything else | 302 | [github.com/deployah-dev](https://github.com/deployah-dev) |

The Worker runs first (`run_worker_first`) so `/?go-get=1` is not
`index.html`. Unknown paths 302 to GitHub. R2 keys drop the leading
slash (`demos/nginx.gif`, `schemas/v1-alpha.5/manifest.json`).

## Develop

Nix (`flake.nix`). Allow `.envrc` if you use direnv.

```sh
nix develop        # Node
nix develop .#demo # plus deployah, VHS, ffmpeg
npm install
npm run preview    # Vite landing
npm run dev        # Worker + assets
```

## Deploy

R2 bucket `deployah`. Custom domain in `wrangler.toml`. Then:

```sh
npm run deploy
```

## Demos and schemas

Docker or Podman, then `nix run .#demo` and `nix run .#publish-demo`.
See [demos/README.md](demos/README.md).

Put schemas at `schemas/v1-alpha.5/manifest.json` (and the matching
`$id`). Editors:

```yaml
# $schema: https://deployah.dev/schemas/v1-alpha.5/manifest.json
```
