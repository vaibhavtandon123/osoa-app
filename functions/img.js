// Cached image endpoint: GET /img?id=FILEID
// The first request fetches the image from Apps Script (only files inside the app's public image folders);
// after that Cloudflare's edge cache serves it to everyone for 30 days, and browsers keep it for 10 days.
// Image ids never change content, so caching is safe.

const TIMEOUT_MS = 45000;

export async function onRequestGet(context) {
  const { request, env } = context;
  const url = new URL(request.url);
  const id = url.searchParams.get("id");
  if (!id || !/^[A-Za-z0-9_-]{10,100}$/.test(id) || !env.APPS_SCRIPT_URL) return new Response("", { status: 404 });

  let cache = null;
  const key = new Request(url.origin + "/img?id=" + id, { method: "GET" });
  try { cache = caches.default; const hit = await cache.match(key); if (hit) return hit; } catch (_) { cache = null; }

  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), TIMEOUT_MS);
  try {
    const r = await fetch(env.APPS_SCRIPT_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ fn: "api_image", arg: id, _k: env.PROXY_KEY || undefined, _ip: request.headers.get("CF-Connecting-IP") || "" }),
      redirect: "follow",
      signal: ac.signal,
    });
    const data = await r.json();
    const dataUrl = data && data.r;
    if (!dataUrl || typeof dataUrl !== "string" || dataUrl.indexOf("base64,") < 0) return new Response("", { status: 404 });
    const comma = dataUrl.indexOf(",");
    const contentType = dataUrl.substring(5, comma).split(";")[0] || "image/jpeg";
    const bin = atob(dataUrl.substring(comma + 1));
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    const res = new Response(bytes, {
      status: 200,
      headers: {
        "Content-Type": contentType,
        "Cache-Control": "public, max-age=864000, s-maxage=2592000, immutable",
        "X-Content-Type-Options": "nosniff",
      },
    });
    if (cache) { try { context.waitUntil(cache.put(key, res.clone())); } catch (_) {} }
    return res;
  } catch (err) {
    return new Response("", { status: 404 });
  } finally {
    clearTimeout(timer);
  }
}
