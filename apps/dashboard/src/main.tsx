import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter, HashRouter } from "react-router-dom";
import App from "./App";
import "./styles.css";

const isNativeShell = window.location.protocol === "file:" || "Capacitor" in window;
const Router = isNativeShell ? HashRouter : BrowserRouter;

if (isNativeShell && window.location.hash.length === 0) {
  window.location.hash = "/wallet";
}

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <Router>
      <App />
    </Router>
  </React.StrictMode>,
);
