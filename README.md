# deployah.dev

Cloudflare Worker for [deployah.dev](https://deployah.dev): Go module vanity
import, demo GIFs, and JSON Schema hosting.

## What it serves

| Path | Source | Purpose |
| --- | --- | --- |
| `/?go-get=1` or `/deployah?go-get=1` | Worker HTML | Vanity import for `deployah.dev/deployah` |
| `/demos/*` | R2 bucket `deployah` | README / docs demo GIFs (e.g. `/demos/nginx.gif`) |
| `/schemas/*` | R2 bucket `deployah` | Published JSON Schemas (matches schema `$id`) |
| everything else | 302 | [github.com/deployah-dev](https://github.com/deployah-dev) |

R2 object keys match the URL path without the leading slash
(`demos/nginx.gif`, `schemas/v1-alpha.2/manifest.json`, ...).

## Layout (same idea as [nabat.dev](https://github.com/nabat-dev/nabat.dev))

```text
src/index.ts      Worker entry
wrangler.toml     Routes + R2 binding
package.json      wrangler scripts
```

## Develop

```sh
npm install
npm run dev
```

## Deploy

1. Create an R2 bucket named `deployah` in the Cloudflare account.
2. Point the `deployah.dev` zone at this Worker (custom domain in `wrangler.toml`).
3. Deploy:

```sh
npm run deploy
```

## Uploading assets

From the [deployah](https://github.com/deployah-dev/deployah) repo:

```sh
# Demo GIFs (after nix run .#demo)
export R2_ACCESS_KEY_ID=...
export R2_SECRET_ACCESS_KEY=...
export R2_ENDPOINT_URL=...
export R2_BUCKET=deployah
export R2_DEST_PATH=demos/
nix run .#publish-demo
```

Schemas should be synced under the `schemas/` prefix so they match Worker paths
and the `$id` fields in the repo, for example:

- `schemas/v1-alpha.2/manifest.json`
- `schemas/v1-alpha.2/environments.json`
- `schemas/platform/v1-alpha.1/platform.json`

Then editors can use:

```yaml
# $schema: https://deployah.dev/schemas/v1-alpha.2/manifest.json
```
