/* NMS · service worker
   Guarda o app para abrir rápido (e até sem internet) e detecta versões novas.
   Para publicar uma atualização: mude o número em VERSAO (e em config.js) e envie os arquivos de novo. */
const VERSAO = "1.3.0";
const CACHE = "nms-" + VERSAO;
const ARQUIVOS = ["./", "./index.html", "./config.js", "./nms-cloud.js", "./manifest.webmanifest", "./icons/icon-192.png", "./icons/icon-512.png", "./icons/maskable-512.png", "./icons/favicon-32.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ARQUIVOS)));
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith("nms-") && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener("message", e => { if (e.data === "atualizar") self.skipWaiting(); });
self.addEventListener("fetch", e => {
  const req = e.request, url = new URL(req.url);
  if (req.method !== "GET") return;
  if (/supabase\.co$/.test(url.hostname) || url.pathname.includes("/auth/") || url.pathname.includes("/rest/") || url.pathname.includes("/realtime/")) return; // dados sempre ao vivo
  if (url.origin === location.origin) {
    // arquivos do app: tenta a rede primeiro (para pegar a versão nova) e usa o guardado se estiver sem internet
    e.respondWith(fetch(req).then(r => { const cp = r.clone(); caches.open(CACHE).then(c => c.put(req, cp)); return r; }).catch(() => caches.match(req).then(r => r || caches.match("./index.html"))));
  } else {
    // bibliotecas e fontes: usa o guardado e atualiza em segundo plano
    e.respondWith(caches.match(req).then(hit => { const net = fetch(req).then(r => { if (r.ok || r.type === "opaque") { const cp = r.clone(); caches.open(CACHE).then(c => c.put(req, cp)); } return r; }).catch(() => hit); return hit || net; }));
  }
});
