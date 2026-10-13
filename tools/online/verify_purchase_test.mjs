// Prueba de la función de borde «verify-purchase» (supabase/functions/verify-purchase/handler.ts) con Node, sin Google ni Supabase de verdad:
// firma el JWT con una clave RSA de prueba y comprueba la firma, simula las respuestas de Google Play y las reglas del manejador (sesión, productos, recibos repetidos, errores).
// Uso: node tools/online/verify_purchase_test.mjs      (Node 22.18 o más nuevo: importa el .ts directo)
import { generateKeyPairSync, createVerify } from 'node:crypto'
import assert from 'node:assert/strict'
import { b64url, googleAccessToken, makeHandler, pemToDer, PRODUCTS, sha256Hex, verifyPlayPurchase } from '../../supabase/functions/verify-purchase/handler.ts'

let fails = 0
async function check(name, fn) {
  try {
    await fn()
    console.log('OK   ' + name)
  } catch (e) {
    fails++
    console.log('FALLA ' + name + ' → ' + (e && e.message ? e.message : e))
  }
}

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 })
const pem = privateKey.export({ type: 'pkcs8', format: 'pem' })
const sa = { client_email: 'play-verifier@dream-racing.iam.gserviceaccount.com', private_key: pem }

await check('b64url y pemToDer', () => {
  assert.equal(b64url('hola?>'), 'aG9sYT8-')
  const der = pemToDer(pem)
  assert.ok(der.length > 1000)
})

await check('sha256Hex da el hash de siempre', async () => {
  assert.equal(await sha256Hex('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
})

await check('el token de acceso de Google: JWT RS256 con la firma correcta y los datos de la cuenta de servicio', async () => {
  let seen
  const fetchFn = async (url, init) => {
    seen = { url, init }
    return new Response(JSON.stringify({ access_token: 'ya29.token', expires_in: 3600 }), { status: 200 })
  }
  const t = await googleAccessToken(sa, fetchFn, 1000000)
  assert.equal(t.token, 'ya29.token')
  assert.ok(t.exp > 1000000)
  assert.equal(seen.url, 'https://oauth2.googleapis.com/token')
  const form = new URLSearchParams(seen.init.body)
  assert.equal(form.get('grant_type'), 'urn:ietf:params:oauth:grant-type:jwt-bearer')
  const [h, c, s] = form.get('assertion').split('.')
  const claims = JSON.parse(Buffer.from(c, 'base64url').toString())
  assert.equal(claims.iss, sa.client_email)
  assert.equal(claims.scope, 'https://www.googleapis.com/auth/androidpublisher')
  assert.equal(claims.aud, 'https://oauth2.googleapis.com/token')
  assert.equal(claims.exp - claims.iat, 3600)
  assert.equal(JSON.parse(Buffer.from(h, 'base64url').toString()).alg, 'RS256')
  const v = createVerify('RSA-SHA256')
  v.update(h + '.' + c)
  assert.ok(v.verify(publicKey, Buffer.from(s, 'base64url')), 'la firma no coincide')
})

await check('sin cuenta de servicio configurada, error claro', async () => {
  await assert.rejects(() => googleAccessToken({}, fetch, 1), /GOOGLE_PLAY_SERVICE_ACCOUNT/)
})

await check('si Google rechaza el token de acceso, se corta', async () => {
  const fetchFn = async () => new Response('no', { status: 401 })
  await assert.rejects(() => googleAccessToken(sa, fetchFn, 1), /401/)
})

const mk = (status, body) => async (url, init) => {
  mk.last = { url, init }
  return new Response(JSON.stringify(body), { status })
}

await check('Google: compra pagada → ok y consulta la dirección correcta', async () => {
  const r = await verifyPlayPurchase({ fetchFn: mk(200, { purchaseState: 0, orderId: 'GPA.1', consumptionState: 0 }), accessToken: 'tk', packageName: 'com.srg.dreamracing', productId: 'dr_coins_m', token: 'abc/def==' })
  assert.deepEqual(r, { ok: true, orderId: 'GPA.1' })
  assert.equal(mk.last.url, 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.srg.dreamracing/purchases/products/dr_coins_m/tokens/abc%2Fdef%3D%3D')
  assert.equal(mk.last.init.headers.Authorization, 'Bearer tk')
})

await check('Google: cancelada, pendiente, inexistente y caída', async () => {
  const f = (st, body) => verifyPlayPurchase({ fetchFn: mk(st, body), accessToken: 'tk', packageName: 'p', productId: 'x', token: 'tttttttttt' })
  assert.equal((await f(200, { purchaseState: 1 })).reason, 'compra cancelada')
  assert.equal((await f(200, { purchaseState: 2 })).reason, 'compra pendiente')
  assert.equal((await f(404, {})).ok, false)
  assert.equal((await f(410, {})).reason, 'recibo no encontrado')
  assert.match((await f(500, {})).reason, /500/)
})

// ───── el manejador completo ─────
function deps(over = {}) {
  const calls = { grant: [], verify: [] }
  const d = {
    products: PRODUCTS,
    getUser: async (auth) => (auth === 'Bearer buena' ? { id: 'user-1' } : null),
    verify: async (product, token) => {
      calls.verify.push([product, token])
      return token.startsWith('valido') ? { ok: true } : { ok: false, reason: 'recibo inválido' }
    },
    grant: async (uid, product, hash) => {
      calls.grant.push([uid, product, hash])
      return { credits: 17000, cars: {}, iap: {}, granted: 12000 }
    },
    ...over,
  }
  return { d, calls }
}
const req = (body, auth = 'Bearer buena', method = 'POST') => new Request('https://x.supabase.co/functions/v1/verify-purchase', { method, headers: { Authorization: auth, 'Content-Type': 'application/json' }, body: method === 'POST' ? JSON.stringify(body) : undefined })

await check('compra válida: se verifica con Google y se acredita con el hash del recibo (no con el recibo)', async () => {
  const { d, calls } = deps()
  const res = await makeHandler(d)(req({ product_id: 'dr_coins_m', purchase_token: 'valido-token-123456' }))
  assert.equal(res.status, 200)
  const j = await res.json()
  assert.equal(j.ok, true)
  assert.equal(j.state.credits, 17000)
  assert.deepEqual(calls.verify, [['dr_coins_m', 'valido-token-123456']])
  assert.equal(calls.grant.length, 1)
  assert.equal(calls.grant[0][0], 'user-1')
  assert.equal(calls.grant[0][1], 'dr_coins_m')
  assert.equal(calls.grant[0][2], await sha256Hex('valido-token-123456'))
  assert.ok(!JSON.stringify(calls.grant).includes('valido-token-123456'))
})

await check('sin sesión (o anónima): 401 y no se consulta a Google ni se acredita', async () => {
  const { d, calls } = deps()
  const res = await makeHandler(d)(req({ product_id: 'dr_coins_m', purchase_token: 'valido-token-123456' }, 'Bearer mala'))
  assert.equal(res.status, 401)
  assert.equal(calls.verify.length + calls.grant.length, 0)
})

await check('producto que no se vende o recibo absurdo: 400', async () => {
  const { d, calls } = deps()
  const h = makeHandler(d)
  assert.equal((await h(req({ product_id: 'dr_gratis', purchase_token: 'valido-token-123456' }))).status, 400)
  assert.equal((await h(req({ product_id: 'dr_coins_m', purchase_token: 'x' }))).status, 400)
  assert.equal((await h(req({ product_id: 'dr_coins_m', purchase_token: 'x'.repeat(5000) }))).status, 400)
  assert.equal((await h(new Request('https://x', { method: 'POST', headers: { Authorization: 'Bearer buena' }, body: 'no es json' }))).status, 400)
  assert.equal(calls.verify.length + calls.grant.length, 0)
})

await check('recibo inválido: 402 y no se acredita', async () => {
  const { d, calls } = deps()
  const res = await makeHandler(d)(req({ product_id: 'car_hyper', purchase_token: 'trucho-token-1234567' }))
  assert.equal(res.status, 402)
  assert.equal(calls.grant.length, 0)
})

await check('si Google no contesta: 502 (el juego reintenta al abrir) y no se acredita', async () => {
  const { d, calls } = deps({ verify: async () => { throw new Error('timeout') } })
  const res = await makeHandler(d)(req({ product_id: 'dr_full', purchase_token: 'valido-token-123456' }))
  assert.equal(res.status, 502)
  assert.equal(calls.grant.length, 0)
})

await check('si la base rechaza el crédito: 400 con el motivo', async () => {
  const { d } = deps({ grant: async () => { throw new Error('producto desconocido') } })
  const res = await makeHandler(d)(req({ product_id: 'dr_full', purchase_token: 'valido-token-123456' }))
  assert.equal(res.status, 400)
  assert.match((await res.json()).error, /producto desconocido/)
})

await check('CORS y métodos', async () => {
  const { d } = deps()
  const h = makeHandler(d)
  assert.equal((await h(req(null, '', 'OPTIONS'))).status, 200)
  assert.equal((await h(req(null, 'Bearer buena', 'GET'))).status, 405)
})

await check('los productos de la función son los mismos que vende el juego y que acepta la base', async () => {
  const fs = await import('node:fs')
  const gd = fs.readFileSync(new URL('../../godot/game/store/products.gd', import.meta.url), 'utf8')
  const inGame = [...gd.matchAll(/^\t"([a-z0-9_]+)": \{"kind"/gm)].map((m) => m[1]).sort()
  assert.deepEqual([...PRODUCTS].sort(), inGame)
  const sql = fs.readFileSync(new URL('../../supabase/migrations/20261014000000_account_economy.sql', import.meta.url), 'utf8')
  for (const p of PRODUCTS) assert.ok(sql.includes("'" + p + "'"), 'la migración no conoce ' + p)
})

console.log(fails === 0 ? 'VERIFY_PURCHASE_TEST OK' : 'VERIFY_PURCHASE_TEST FALLÓ (' + fails + ')')
process.exit(fails === 0 ? 0 : 1)
