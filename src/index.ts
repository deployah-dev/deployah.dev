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
  ASSETS: R2Bucket;
}

function contentTypeForKey(key: string): string | undefined {
  if (key.endsWith(".gif")) return "image/gif";
  if (key.endsWith(".png")) return "image/png";
  if (key.endsWith(".mp4")) return "video/mp4";
  if (key.endsWith(".webm")) return "video/webm";
  if (key.endsWith(".json")) return "application/schema+json";
  return undefined;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    if (url.searchParams.get("go-get") === "1") {
      return new Response(goImportHTML, {
        headers: { "content-type": "text/html; charset=utf-8" },
      });
    }

    // /schemas/ matches $id in deployah JSON Schema files (plural).
    if (path.startsWith("/demos/") || path.startsWith("/schemas/")) {
      const key = path.slice(1);
      const object = await env.ASSETS.get(key);
      if (object === null) {
        return new Response("Not Found", { status: 404 });
      }
      const headers = new Headers();
      object.writeHttpMetadata(headers);
      headers.set("etag", object.httpEtag);
      headers.set("cache-control", "public, max-age=86400");
      if (!headers.has("content-type")) {
        const ct = contentTypeForKey(key);
        if (ct) headers.set("content-type", ct);
      }
      return new Response(object.body, { headers });
    }

    return Response.redirect(ORG, 302);
  },
} satisfies ExportedHandler<Env>;
