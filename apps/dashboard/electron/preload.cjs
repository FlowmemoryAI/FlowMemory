const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("flowmemoryDesktop", {
  app: "FlowMemory",
  platform: process.platform,
  packaged: process.env.NODE_ENV !== "development",
  getLocalWallet: () => ipcRenderer.invoke("flowmemory-app:get-local-wallet"),
  createLocalWallet: (payload) => ipcRenderer.invoke("flowmemory-app:create-local-wallet", payload),
});
