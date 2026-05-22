const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("flowchainDesktop", {
  app: "FlowMemory Operator",
  platform: process.platform,
  packaged: process.env.NODE_ENV !== "development",
  getLocalWallet: () => ipcRenderer.invoke("flowchain-wallet:get-local-wallet"),
  createLocalWallet: (payload) => ipcRenderer.invoke("flowchain-wallet:create-local-wallet", payload),
});
