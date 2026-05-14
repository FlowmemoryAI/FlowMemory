const { app, BrowserWindow, Menu, shell } = require("electron");
const path = require("node:path");

const isDev = Boolean(process.env.FLOWCHAIN_WALLET_DESKTOP_DEV_URL);

function createWalletWindow() {
  const window = new BrowserWindow({
    width: 1480,
    height: 940,
    minWidth: 1120,
    minHeight: 720,
    title: "Flowchain Wallet",
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
    window.loadURL(`${process.env.FLOWCHAIN_WALLET_DESKTOP_DEV_URL.replace(/\/+$/, "")}/wallet`);
  } else {
    window.loadFile(path.join(__dirname, "..", "dist", "index.html"), { hash: "/wallet" });
  }

  return window;
}

app.setName("Flowchain Wallet");

app.whenReady().then(() => {
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    {
      label: "Flowchain Wallet",
      submenu: [
        { role: "reload" },
        { role: "toggleDevTools" },
        { type: "separator" },
        { role: "quit" },
      ],
    },
  ]));

  createWalletWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWalletWindow();
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});
