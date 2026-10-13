// Dream Racing · función de borde «verify-purchase»: verifica una compra de Google Play y la acredita en la cuenta del jugador.
// Esta parte es LÓGICA PURA (sin Deno ni Supabase): se prueba con Node en tools/online/verify_purchase_test.mjs. La conexión real está en index.ts.
//
// Flujo (docs/CUENTA_Y_ECONOMIA.md): el juego manda {product_id, purchase_token} con la sesión del jugador → se comprueba la sesión (cuenta con correo) → se le pregunta a Google
// Play si ese recibo existe y está pagado → se acredita con account_iap_grant (que sólo puede llamar el servidor y no acredita dos veces el mismo recibo).

export const PRODUCTS = ['dr_coins_s', 'dr_coins_m', 'dr_coins_l', 'dr_coins_xl', 'dr_adventure', 'dr_full', 'dr_garage', 'car_truck', 'car_gt3', 'car_hyper']

export const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } })
}

export function b64url(data: Uint8Array | string): string {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data
  let bin = ''
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i])
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

export function pemToDer(pem: string): Uint8Array {
  const body = pem.replace(/-----BEGIN [A-Z ]+-----/g, '').replace(/-----END [A-Z ]+-----/g, '').replace(/\s+/g, '')
  const bin = atob(body)
  const out = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i)
  return out
}

export async function sha256Hex(text: string): Promise<string> {
  const h = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text)))
  return Array.from(h).map((b) => b.toString(16).padStart(2, '0')).join('')
}

// Token de acceso de la cuenta de servicio de Google (JWT firmado con RS256 que se cambia en oauth2.googleapis.com por un token de una hora)
export async function googleAccessToken(sa: { client_email: string; private_key: string }, fetchFn: typeof fetch, nowSec: number): Promise<{ token: string; exp: number }> {
  if (!sa || !sa.client_email || !sa.private_key) throw new Error('falta la cuenta de servicio de Google Play (secreto GOOGLE_PLAY_SERVICE_ACCOUNT)')
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: nowSec,
    exp: nowSec + 3600,
  }))
  const unsigned = header + '.' + claims
  const key = await crypto.subtle.importKey('pkcs8', pemToDer(sa.private_key), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'])
  const sig = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned)))
  const assertion = unsigned + '.' + b64url(sig)
  const r = await fetchFn('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }).toString(),
  })
  if (!r.ok) throw new Error('Google no dio el token de acceso (' + r.status + ')')
  const j = await r.json()
  return { token: String(j.access_token), exp: nowSec + Math.max(60, Number(j.expires_in ?? 3600) - 120) }
}

// ¿Existe ese recibo y está pagado? (purchases.products.get de la API de Google Play Developer)
export async function verifyPlayPurchase(o: { fetchFn: typeof fetch; accessToken: string; packageName: string; productId: string; token: string }): Promise<{ ok: boolean; reason?: string; orderId?: string }> {
  const url = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' + encodeURIComponent(o.packageName) +
    '/purchases/products/' + encodeURIComponent(o.productId) + '/tokens/' + encodeURIComponent(o.token)
  const r = await o.fetchFn(url, { headers: { Authorization: 'Bearer ' + o.accessToken } })
  if (r.status === 404 || r.status === 410 || r.status === 400) return { ok: false, reason: 'recibo no encontrado' }
  if (!r.ok) return { ok: false, reason: 'Google respondió ' + r.status }
  const j = await r.json()
  if (j.purchaseState !== 0) return { ok: false, reason: j.purchaseState === 2 ? 'compra pendiente' : 'compra cancelada' }
  return { ok: true, orderId: String(j.orderId ?? '') }
}

export type Deps = {
  products: string[]
  getUser: (authHeader: string) => Promise<{ id: string } | null>
  verify: (product: string, token: string) => Promise<{ ok: boolean; reason?: string }>
  grant: (userId: string, product: string, tokenHash: string) => Promise<unknown>
}

export function makeHandler(deps: Deps): (req: Request) => Promise<Response> {
  return async function handle(req: Request): Promise<Response> {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
    if (req.method !== 'POST') return json({ ok: false, error: 'método no permitido' }, 405)
    let body: Record<string, unknown>
    try {
      body = await req.json()
    } catch (_e) {
      return json({ ok: false, error: 'cuerpo inválido' }, 400)
    }
    const product = String(body.product_id ?? '')
    const token = String(body.purchase_token ?? '')
    if (!deps.products.includes(product) || token.length < 10 || token.length > 4096) return json({ ok: false, error: 'datos inválidos' }, 400)
    const user = await deps.getUser(req.headers.get('Authorization') ?? '')
    if (!user) return json({ ok: false, error: 'sin sesión' }, 401)
    let g: { ok: boolean; reason?: string }
    try {
      g = await deps.verify(product, token)
    } catch (e) {
      return json({ ok: false, error: 'no se pudo consultar a Google: ' + String((e as Error).message ?? e).slice(0, 120) }, 502)
    }
    if (!g.ok) return json({ ok: false, error: g.reason ?? 'recibo inválido' }, 402)
    try {
      const state = await deps.grant(user.id, product, await sha256Hex(token))
      return json({ ok: true, state }, 200)
    } catch (e) {
      return json({ ok: false, error: String((e as Error).message ?? e).slice(0, 120) }, 400)
    }
  }
}
