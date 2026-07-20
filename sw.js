/* Service worker de Finances.
   Estratègia: network-first per a l'HTML (així els canvis que puges a GitHub
   arriben de seguida) i cache-first per a la resta (icones, manifest). */
const CACHE = 'finances-v1';
const CORE = ['./', './index.html', './manifest.webmanifest',
              './img/icon-192.png', './img/icon-512.png', './img/favicon.svg'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;                       // el POST a l'Apps Script mai es cacheja
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;             // res de tercers

  const isDoc = req.mode === 'navigate' || url.pathname.endsWith('.html');
  if (isDoc) {
    e.respondWith(
      fetch(req)
        .then(r => { caches.open(CACHE).then(c => c.put(req, r.clone())); return r; })
        .catch(() => caches.match(req).then(r => r || caches.match('./index.html')))
    );
  } else {
    e.respondWith(
      caches.match(req).then(r => r || fetch(req).then(resp => {
        caches.open(CACHE).then(c => c.put(req, resp.clone()));
        return resp;
      }))
    );
  }
});
