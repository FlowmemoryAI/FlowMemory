const { app, BrowserWindow, Menu, ipcMain, shell } = require("electron");
const fs = require("node:fs/promises");
const http = require("node:http");
const path = require("node:path");
const { createLocalDesktopWallet, publicDesktopWalletStatus } = require("./wallet-store.cjs");

const desktopDevUrl = process.env.FLOWMEMORY_DESKTOP_DEV_URL;
const isDev = Boolean(desktopDevUrl);
let staticServer;

const contentTypes = new Map([
  [".css", "text/css; charset=utf-8"],
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".png", "image/png"],
  [".svg", "image/svg+xml; charset=utf-8"],
  [".woff", "font/woff"],
  [".woff2", "font/woff2"],
]);

function contentTypeFor(filePath) {
  return contentTypes.get(path.extname(filePath).toLowerCase()) ?? "application/octet-stream";
}

function startBundledStaticServer() {
  if (staticServer !== undefined) {
    return staticServer;
  }

  const distDir = path.resolve(__dirname, "..", "dist");
  staticServer = new Promise((resolve, reject) => {
    const server = http.createServer(async (req, res) => {
      try {
        const requestUrl = new URL(req.url ?? "/", "http://127.0.0.1");
        const rawPath = decodeURIComponent(requestUrl.pathname);
        const assetPath = rawPath === "/" || path.extname(rawPath) === "" ? "/index.html" : rawPath;
        const filePath = path.resolve(distDir, `.${assetPath}`);

        if (!filePath.startsWith(distDir)) {
          res.writeHead(403, { "content-type": "text/plain; charset=utf-8" });
          res.end("Forbidden");
          return;
        }

        const body = await fs.readFile(filePath);
        res.writeHead(200, {
          "cache-control": "no-store",
          "content-type": contentTypeFor(filePath),
        });
        res.end(body);
      } catch {
        res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
        res.end("Not found");
      }
    });

    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      if (typeof address !== "object" || address === null) {
        reject(new Error("FlowMemory static server did not bind to a local port."));
        return;
      }
      resolve({ server, origin: `http://127.0.0.1:${address.port}` });
    });
  });

  return staticServer;
}

async function createWalletWindow() {
  const window = new BrowserWindow({
    width: 1480,
    height: 940,
    minWidth: 1120,
    minHeight: 720,
    title: "FlowMemory",
    backgroundColor: "#fff9ee",
    show: false,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      preload: path.join(__dirname, "preload.cjs"),
    },
  });

  window.once("ready-to-show", () => {
    window.show();
  });

  window.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith("http://127.0.0.1") || url.startsWith("http://localhost")) {
      return { action: "allow" };
    }
    shell.openExternal(url).catch(() => undefined);
    return { action: "deny" };
  });

  window.webContents.on("will-navigate", (event, url) => {
    const allowed = url.startsWith("file://")
      || url.startsWith("http://127.0.0.1")
      || url.startsWith("http://localhost")
      || url.startsWith("http://192.168.");
    if (!allowed) {
      event.preventDefault();
      shell.openExternal(url).catch(() => undefined);
    }
  });

  if (isDev) {
    window.loadURL(`${desktopDevUrl.replace(/\/+$/, "")}/wallet`);
  } else {
    const { origin } = await startBundledStaticServer();
    window.loadURL(`${origin}/wallet`);
  }

  return window;
}

app.setName("FlowMemory");

app.whenReady().then(() => {
  ipcMain.handle("flowmemory-app:get-local-wallet", () => publicDesktopWalletStatus(app.getPath("userData")));
  ipcMain.handle("flowmemory-app:create-local-wallet", (_event, payload) => createLocalDesktopWallet(app.getPath("userData"), payload));

  Menu.setApplicationMenu(Menu.buildFromTemplate([
    {
      label: "FlowMemory",
      submenu: [
        { role: "reload" },
        { role: "toggleDevTools" },
        { type: "separator" },
        { role: "quit" },
      ],
    },
  ]));

  createWalletWindow().catch((error) => {
    console.error(error);
    app.quit();
  });

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWalletWindow().catch((error) => {
        console.error(error);
        app.quit();
      });
    }
  });
});

app.on("window-all-closed", () => {
  staticServer?.then(({ server }) => server.close()).catch(() => undefined);
  if (process.platform !== "darwin") {
    app.quit();
  }
});
