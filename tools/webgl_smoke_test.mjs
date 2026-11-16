import fs from "node:fs";

const cdpBase = process.env.DINO_CDP || "http://127.0.0.1:9223";
const output = process.argv[2] || "Builds/webgl-smoke.png";
const waitMs = Number(process.argv[3] || 20000);

const targets = await (await fetch(`${cdpBase}/json/list`)).json();
const page = targets.find(
  (target) => target.type === "page" && target.url.includes("127.0.0.1:8123")
) || targets.find((target) => target.type === "page");

if (!page) {
  throw new Error("No debuggable page found");
}

const ws = new WebSocket(page.webSocketDebuggerUrl);
const pending = new Map();
const logs = [];
let nextId = 0;

ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  if (message.id && pending.has(message.id)) {
    const { resolve, reject } = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) reject(new Error(JSON.stringify(message.error)));
    else resolve(message.result);
    return;
  }
  if (message.method === "Runtime.consoleAPICalled") {
    logs.push(
      `[console:${message.params.type}] ` +
        message.params.args.map((arg) => arg.value ?? arg.description ?? "").join(" ")
    );
  }
  if (message.method === "Runtime.exceptionThrown") {
    logs.push(`[exception] ${message.params.exceptionDetails.text}`);
  }
};

function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++nextId;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
  });
}

await new Promise((resolve, reject) => {
  ws.onopen = resolve;
  ws.onerror = reject;
});

await send("Runtime.enable");
await send("Page.enable");
await new Promise((resolve) => setTimeout(resolve, waitMs));

await send("Runtime.evaluate", {
  expression: 'document.querySelector("canvas")?.focus()',
});

if (process.env.DINO_CLICK) {
  const [x, y] = process.env.DINO_CLICK.split(",").map(Number);
  await send("Input.dispatchMouseEvent", { type: "mouseMoved", x, y });
  await send("Input.dispatchMouseEvent", { type: "mousePressed", x, y, button: "left", clickCount: 1 });
  await send("Input.dispatchMouseEvent", { type: "mouseReleased", x, y, button: "left", clickCount: 1 });
  await new Promise((resolve) => setTimeout(resolve, 8000));
}

if (process.env.DINO_KEY) {
  const key = process.env.DINO_KEY;
  const keyCode = key === "Enter" ? 13 : key === " " ? 32 : 0;
  const code = key === " " ? "Space" : key;
  await send("Input.dispatchKeyEvent", {
    type: "keyDown",
    key,
    code,
    windowsVirtualKeyCode: keyCode,
    nativeVirtualKeyCode: keyCode,
  });
  await send("Input.dispatchKeyEvent", {
    type: "keyUp",
    key,
    code,
    windowsVirtualKeyCode: keyCode,
    nativeVirtualKeyCode: keyCode,
  });
  await new Promise((resolve) => setTimeout(resolve, 8000));
}

const state = await send("Runtime.evaluate", {
  expression: `({
    title: document.title,
    canvas: !!document.querySelector("canvas"),
    width: document.querySelector("canvas")?.width,
    height: document.querySelector("canvas")?.height,
    loadingVisible: getComputedStyle(document.querySelector("#unity-loading-bar")).display,
    warning: document.querySelector("#unity-warning")?.innerText || ""
  })`,
  returnByValue: true,
});

const screenshot = await send("Page.captureScreenshot", { format: "png" });
fs.writeFileSync(output, Buffer.from(screenshot.data, "base64"));

console.log(JSON.stringify({ state: state.result.value, logs }, null, 2));
ws.close();
