import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";

const demosOut = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "demos/out");

const demoTypes = {
  ".mp4": "video/mp4",
  ".gif": "image/gif",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".webp": "image/webp",
};

function serveDemosOut() {
  function handle(req, res, next) {
    const raw = req.url?.split("?")[0] ?? "";
    if (!raw.startsWith("/demos/")) return next();
    const name = decodeURIComponent(raw.slice("/demos/".length));
    if (!name || name.includes("/") || name.includes("\\") || name.includes("..")) {
      return next();
    }
    const filePath = path.join(demosOut, name);
    if (!filePath.startsWith(demosOut + path.sep)) return next();
    let stat;
    try {
      stat = fs.statSync(filePath);
    } catch {
      return next();
    }
    if (!stat.isFile()) return next();
    const mime = demoTypes[path.extname(name).toLowerCase()] ?? "application/octet-stream";
    const range = req.headers.range;
    if (range) {
      const match = /^bytes=(\d*)-(\d*)$/.exec(range);
      if (!match) {
        res.statusCode = 416;
        res.end();
        return;
      }
      const start = match[1] ? Number(match[1]) : 0;
      const end = match[2] ? Number(match[2]) : stat.size - 1;
      if (start >= stat.size || end >= stat.size || start > end) {
        res.statusCode = 416;
        res.setHeader("Content-Range", `bytes */${stat.size}`);
        res.end();
        return;
      }
      res.writeHead(206, {
        "Content-Type": mime,
        "Content-Range": `bytes ${start}-${end}/${stat.size}`,
        "Accept-Ranges": "bytes",
        "Content-Length": end - start + 1,
      });
      fs.createReadStream(filePath, { start, end }).pipe(res);
      return;
    }
    res.writeHead(200, {
      "Content-Type": mime,
      "Content-Length": stat.size,
      "Accept-Ranges": "bytes",
    });
    fs.createReadStream(filePath).pipe(res);
  }

  return {
    name: "serve-demos-out",
    configureServer(server) {
      server.middlewares.use(handle);
    },
    configurePreviewServer(server) {
      server.middlewares.use(handle);
    },
  };
}

export default defineConfig({
  plugins: [tailwindcss(), serveDemosOut()],
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
});
