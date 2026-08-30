const ORG = "https://github.com/deployah-dev";
const REPO = "https://github.com/deployah-dev/deployah";
const MODULE = "deployah.dev/deployah";

const goImportHTML = `<!DOCTYPE html>
<html>
<head>
<meta name="go-import" content="${MODULE} git ${REPO}">
<meta name="go-source" content="${MODULE} _ ${REPO}/tree/main{/dir} ${REPO}/blob/main{/file}#L{line}">
<meta http-equiv="refresh" content="0; url=${ORG}">
</head>
<body>Redirecting to <a href="${ORG}">${ORG}</a></body>
</html>`;

export interface Env {
  ASSETS: Fetcher;
  MEDIA: R2Bucket;
}

function contentTypeForKey(key: string): string | undefined {
  if (key.endsWith(".gif")) return "image/gif";
  if (key.endsWith(".png")) return "image/png";
  if (key.endsWith(".jpg") || key.endsWith(".jpeg")) return "image/jpeg";
  if (key.endsWith(".webp")) return "image/webp";
  if (key.endsWith(".mp4")) return "video/mp4";
  if (key.endsWith(".webm")) return "video/webm";
  if (key.endsWith(".json")) return "application/schema+json";
  return undefined;
}

function withSecurityHeaders(response: Response): Response {
  const headers = new Headers(response.headers);
  headers.set("X-Content-Type-Options", "nosniff");
  headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    if (url.searchParams.get("go-get") === "1") {
      return withSecurityHeaders(
        new Response(goImportHTML, {
          headers: { "content-type": "text/html; charset=utf-8" },
        }),
      );
    }

    // /schemas/ matches $id in deployah JSON Schema files (plural).
    if (path.startsWith("/demos/") || path.startsWith("/schemas/")) {
      const key = path.slice(1);
      const object = await env.MEDIA.get(key);
      if (object === null) {
        return withSecurityHeaders(new Response("Not Found", { status: 404 }));
      }
      const headers = new Headers();
      object.writeHttpMetadata(headers);
      headers.set("etag", object.httpEtag);
      headers.set("cache-control", "public, max-age=3600, stale-while-revalidate=86400");
      if (!headers.has("content-type")) {
        const ct = contentTypeForKey(key);
        if (ct) headers.set("content-type", ct);
      }
      return withSecurityHeaders(new Response(object.body, { headers }));
    }

    const asset = await env.ASSETS.fetch(request);
    if (asset.status !== 404) {
      if (path === "/llms.txt") {
        const headers = new Headers(asset.headers);
        headers.set("content-type", "text/plain; charset=utf-8");
        return withSecurityHeaders(
          new Response(asset.body, {
            status: asset.status,
            statusText: asset.statusText,
            headers,
          }),
        );
      }
      return withSecurityHeaders(asset);
    }

    return withSecurityHeaders(Response.redirect(ORG, 302));
  },
} satisfies ExportedHandler<Env>;
