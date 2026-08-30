import assert from "node:assert/strict";
import { describe, it } from "node:test";
import worker from "./index.ts";

const ORG = "https://github.com/deployah-dev";

function env(opts?: {
  media?: Record<string, { body: string; contentType?: string; etag?: string }>;
  assets?: Record<string, { status?: number; body?: string }>;
}) {
  return {
    MEDIA: {
      async get(key: string) {
        const hit = opts?.media?.[key];
        if (!hit) return null;
        return {
          body: hit.body,
          httpEtag: hit.etag ?? '"x"',
          writeHttpMetadata(headers: Headers) {
            if (hit.contentType) headers.set("content-type", hit.contentType);
          },
        };
      },
    },
    ASSETS: {
      async fetch(request: Request) {
        const path = new URL(request.url).pathname;
        const hit = opts?.assets?.[path];
        if (!hit) return new Response("Not Found", { status: 404 });
        return new Response(hit.body ?? "ok", { status: hit.status ?? 200 });
      },
    },
  };
}

function get(path: string, bindings = env()) {
  return worker.fetch(new Request(`https://deployah.dev${path}`), bindings);
}

describe("worker fetch", () => {
  it("serves the go-import document for go-get=1", async () => {
    const res = await get("/deployah?go-get=1");
    const body = await res.text();
    assert.equal(res.status, 200);
    assert.match(res.headers.get("content-type") ?? "", /text\/html/);
    assert.equal(res.headers.get("x-content-type-options"), "nosniff");
    assert.match(body, /go-import/);
    assert.match(body, /deployah\.dev\/deployah/);
  });

  it("serves MEDIA objects under /demos/ and /schemas/", async () => {
    const bindings = env({
      media: {
        "demos/nginx.mp4": { body: "movie" },
        "schemas/v1-alpha.5/manifest.json": { body: "{}" },
      },
    });
    const movie = await get("/demos/nginx.mp4", bindings);
    assert.equal(movie.status, 200);
    assert.equal(movie.headers.get("content-type"), "video/mp4");
    assert.equal(await movie.text(), "movie");

    const schema = await get("/schemas/v1-alpha.5/manifest.json", bindings);
    assert.equal(schema.status, 200);
    assert.equal(schema.headers.get("content-type"), "application/schema+json");
  });

  it("returns 404 when MEDIA has no object", async () => {
    const res = await get("/demos/missing.mp4");
    assert.equal(res.status, 404);
    assert.equal(res.headers.get("x-content-type-options"), "nosniff");
  });

  it("serves /llms.txt as UTF-8 plain text", async () => {
    const res = await get(
      "/llms.txt",
      env({ assets: { "/llms.txt": { body: "# Deployah\n" } } }),
    );
    assert.equal(res.status, 200);
    assert.equal(res.headers.get("content-type"), "text/plain; charset=utf-8");
    assert.match(await res.text(), /# Deployah/);
  });

  it("returns ASSETS when the file exists", async () => {
    const res = await get(
      "/",
      env({ assets: { "/": { body: "landing" } } }),
    );
    assert.equal(res.status, 200);
    assert.equal(await res.text(), "landing");
    assert.equal(res.headers.get("referrer-policy"), "strict-origin-when-cross-origin");
  });

  it("redirects unknown paths to the GitHub org", async () => {
    const res = await get("/nope");
    assert.equal(res.status, 302);
    assert.equal(res.headers.get("location"), ORG);
  });
});
