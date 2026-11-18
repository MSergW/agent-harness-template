// PROTOTYPE (proto/<topic>): the bar switching the variants — deleted with the branch. No dependencies.
// Only on the prototype's port: UI unit tests load modules without a browser.
if (globalThis.location?.port === "<prototype port>")
  setTimeout(() => {
    const KEY = "proto-<topic>",
      names = { A: "As now", B: "…", C: "…", D: "…" },
      now = localStorage.getItem(KEY) || "A",
      bar = document.createElement("div");
    bar.className = "proto-bar";
    bar.style.cssText =
      "position:fixed;left:12px;bottom:12px;z-index:2147483647;display:flex;gap:4px;align-items:center;" +
      "padding:6px 8px;border-radius:8px;background:#222;color:#fff;font:12px sans-serif;box-shadow:0 2px 8px #0005";
    bar.append("Prototype:");
    for (const k of Object.keys(names)) {
      const b = document.createElement("button");
      b.textContent = k;
      b.title = names[k];
      b.style.minWidth = "28px";
      b.setAttribute("aria-pressed", String(k === now));
      if (k === now) b.style.outline = "2px solid #f5a623";
      b.onclick = () => {
        localStorage.setItem(KEY, k);
        location.reload();
      };
      bar.append(b);
    }
    bar.append(" " + names[now]);
    // A modal dialog sits in the top layer, above any z-index: the bar moves into the open one, and back.
    const place = () => {
      const open = [...document.querySelectorAll("dialog[open]")].pop() || document.body;
      if (bar.parentNode !== open) open.append(bar);
    };
    place();
    new MutationObserver(place).observe(document.body, { subtree: true, attributes: true, attributeFilter: ["open"], childList: true });
  });
