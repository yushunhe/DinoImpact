#!/usr/bin/env node
// Headless wrapper around Pixel It (https://github.com/giventofly/pixelit).
// Usage:
//   node convert.mjs input.png output.png [--scale 8] [--palette file.json]
//                    [--palette-convert] [--grayscale]
//                    [--max-width N] [--max-height N]
//                    [--out-width N] [--out-height N]
//
// --scale          pixel block size, 1..50 (Pixel It default: 8)
// --palette        JSON file containing [[r,g,b], ...]
// --palette-convert  snap every pixel to the palette after pixelating
// --grayscale      desaturate after pixelating
// --max-width/--max-height  resize before pixelation (Pixel It behavior, can blur)
// --out-width/--out-height  nearest-neighbor downscale the result (crisp small sprite)

import { readFile, writeFile, mkdtemp, rm } from "node:fs/promises";
import { spawn } from "node:child_process";
import { tmpdir } from "node:os";
import path from "node:path";

const MIME = {
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".gif": "image/gif",
  ".bmp": "image/bmp",
};

function usage(msg) {
  if (msg) console.error(`error: ${msg}\n`);
  console.error(
    "usage: node convert.mjs input.png output.png [--scale 8] [--palette file.json]\n" +
      "                         [--palette-convert] [--grayscale]\n" +
      "                         [--max-width N] [--max-height N]\n" +
      "                         [--out-width N] [--out-height N]"
  );
  process.exit(1);
}

const args = process.argv.slice(2);
if (args.length < 2) usage("need input and output paths");

const positional = [];
const opts = { scale: 8, paletteConvert: false, grayscale: false };
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  switch (a) {
    case "--scale":
      opts.scale = Number(args[++i]);
      if (!Number.isFinite(opts.scale) || opts.scale < 1 || opts.scale > 50)
        usage("--scale must be 1..50");
      break;
    case "--palette":
      opts.palette = JSON.parse(await readFile(args[++i], "utf8"));
      break;
    case "--palette-convert":
      opts.paletteConvert = true;
      break;
    case "--grayscale":
      opts.grayscale = true;
      break;
    case "--max-width":
      opts.maxWidth = Number(args[++i]);
      break;
    case "--max-height":
      opts.maxHeight = Number(args[++i]);
      break;
    case "--out-width":
      opts.outWidth = Number(args[++i]);
      break;
    case "--out-height":
      opts.outHeight = Number(args[++i]);
      break;
    default:
      if (a.startsWith("--")) usage(`unknown option ${a}`);
      positional.push(a);
  }
}

const [input, output] = positional;
if (!input || !output) usage("need input and output paths");

const ext = path.extname(input).toLowerCase();
const mime = MIME[ext];
if (!mime) usage(`unsupported input extension ${ext}`);

const pixelitSrc = await readFile(new URL("./pixelit.js", import.meta.url), "utf8");
const imageDataUrl = `data:${mime};base64,${(await readFile(input)).toString(
  "base64"
)}`;

const config = `{
    from: img,
    to: document.getElementById("pixelitcanvas"),
    scale: ${opts.scale}${opts.palette ? `,\n    palette: ${JSON.stringify(opts.palette)}` : ""}${
      opts.maxWidth ? `,\n    maxWidth: ${opts.maxWidth}` : ""
    }${opts.maxHeight ? `,\n    maxHeight: ${opts.maxHeight}` : ""}
  }`;

const outW = opts.outWidth ? String(opts.outWidth) : "0";
const outH = opts.outHeight ? String(opts.outHeight) : "0";

const html = `<!doctype html>
<meta charset="utf-8">
<style>html,body{margin:0;background:transparent}canvas,img{display:block}</style>
<img id="pixelitimg" alt="">
<canvas id="pixelitcanvas"></canvas>
<script>${pixelitSrc}</script>
<script>
  const img = document.getElementById("pixelitimg");
  img.onload = () => {
    try {
      const px = new pixelit(${config});
      px.draw().pixelate();
      ${opts.grayscale ? "px.convertGrayscale();" : ""}
      ${opts.paletteConvert ? "px.convertPalette();" : ""}
      const c = document.getElementById("pixelitcanvas");
      let outCanvas = c;
      const outW = ${outW}, outH = ${outH};
      if (outW || outH) {
        const ratio = Math.min(
          outW ? outW / c.width : Infinity,
          outH ? outH / c.height : Infinity
        );
        const nw = Math.max(1, Math.round(c.width * ratio));
        const nh = Math.max(1, Math.round(c.height * ratio));
        outCanvas = document.createElement("canvas");
        outCanvas.width = nw;
        outCanvas.height = nh;
        const octx = outCanvas.getContext("2d");
        octx.imageSmoothingEnabled = false;
        octx.drawImage(c, 0, 0, nw, nh);
      }
      const out = document.createElement("pre");
      out.id = "pixelit-result";
      out.dataset.width = String(outCanvas.width);
      out.dataset.height = String(outCanvas.height);
      out.textContent = outCanvas.toDataURL("image/png");
      document.body.appendChild(out);
      document.title = "PIXELIT_OK";
    } catch (e) {
      document.title = "PIXELIT_ERR " + e.message;
    }
  };
  img.onerror = () => { document.title = "PIXELIT_ERR image load failed"; };
  img.src = ${JSON.stringify(imageDataUrl)};
</script>`;

const workdir = await mkdtemp(path.join(tmpdir(), "pixelit-"));
const htmlPath = path.join(workdir, "page.html");
const profilePath = path.join(workdir, "profile");
await writeFile(htmlPath, html);

function run(cmd, argv) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, argv, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    p.stdout.on("data", (d) => (stdout += d));
    p.stderr.on("data", (d) => (stderr += d));
    p.on("error", reject);
    p.on("close", (code) => resolve({ code, stdout, stderr }));
    setTimeout(() => p.kill("SIGKILL"), 120000).unref();
  });
}

const chrome = process.env.CHROME || "chromium";
try {
  const { code, stdout, stderr } = await run(chrome, [
    "--headless=new",
    "--no-sandbox",
    "--disable-gpu",
    "--disable-dev-shm-usage",
    "--virtual-time-budget=30000",
    `--user-data-dir=${profilePath}`,
    "--dump-dom",
    `file://${htmlPath}`,
  ]);

  const errMatch = stdout.match(/<title>(PIXELIT_ERR[^<]*)<\/title>/);
  if (errMatch) throw new Error(errMatch[1].trim());
  if (!stdout.includes("PIXELIT_OK")) {
    const tail = stderr.trim().slice(-3000);
    throw new Error(
      `conversion did not finish (chromium exit ${code})${tail ? `\n${tail}` : ""}`
    );
  }

  const m = stdout.match(
    /id="pixelit-result"[^>]*data-width="(\d+)"[^>]*data-height="(\d+)"[^>]*>data:image\/png;base64,([A-Za-z0-9+/=]+)/
  );
  if (!m) throw new Error("could not find PNG result in page");
  const png = Buffer.from(m[3], "base64");
  await writeFile(output, png);
  console.log(`wrote ${output} (${m[1]}x${m[2]}, ${png.length} bytes)`);
} finally {
  await rm(workdir, { recursive: true, force: true });
}
