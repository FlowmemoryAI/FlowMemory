const { contextBridge } = require("electron");

contextBridge.exposeInMainWorld("flowchainDesktop", {
  app: "Flowchain Wallet",
  platform: process.platform,
  packaged: process.env.NODE_ENV !== "development",
});
