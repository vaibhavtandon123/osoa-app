// Cloudflare Pages Function — proxies the app's API calls to the Google Apps Script backend.
// The frontend POSTs {fn, arg} to /api; this forwards it to Apps Script and returns the JSON.
// Environment variables (Cloudflare Pages project > Settings > Variables and Secrets, not in this repo):
//   APPS_SCRIPT_URL  the Apps Script web app URL
//   PROXY_KEY        optional shared secret; when Apps Script also has PROXY_KEY set, it refuses calls without it
// The visitor's internet address is passed along so the backend can apply spam / brute-force limits.

const TIMEOUT_MS = 60000;

export async function onRequestPost(context) {
  const { request, env } = context;
  const url = env.APPS_SCRIPT_URL;
  if (!url) return json({ e: "Server not configured (APPS_SCRIPT_URL missing)." });
  let req;
  try { req = JSON.parse(await request.text()); } catch (_) { return json({ e: "Bad request." }); }
  if (!req || typeof req.fn !== "string") return json({ e: "Bad request." });
  const body = JSON.stringify({
    fn: req.fn,
    arg: req.arg,
    _ip: request.headers.get("CF-Connecting-IP") || "",
    _k: env.PROXY_KEY || undefined,
  });
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), TIMEOUT_MS);
  try {
    const upstream = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
      redirect: "follow",
      signal: ac.signal,
    });
    const text = await upstream.text();
    if (!text || text[0] !== "{") return json({ e: "The server is busy. Please try again in a minute." });
    return new Response(text, {
      status: 200,
      headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
    });
  } catch (err) {
    return json({ e: err && err.name === "AbortError" ? "The server took too long to answer. Please try again." : "Could not reach the backend. Please try again." });
  } finally {
    clearTimeout(timer);
  }
}

// Friendly message for GET /api (so hitting it in a browser isn't confusing).
export async function onRequestGet() {
  return json({ ok: true, info: "OSOA Desk API proxy is running." });
}

function json(obj) {
  return new Response(JSON.stringify(obj), {
    status: 200,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
}
