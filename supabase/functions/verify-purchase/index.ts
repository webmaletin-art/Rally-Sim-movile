// Dream Racing · «verify-purchase»: verifica una compra de Google Play y la acredita en la cuenta (créditos o desbloqueo). La lógica está en handler.ts (probada con Node);
// acá sólo se conecta con Supabase y Google. Secretos de la función (supabase secrets set …, o el flujo «Supabase · publicar funciones»):
//   GOOGLE_PLAY_SERVICE_ACCOUNT  el JSON de la cuenta de servicio de Google Cloud con permiso en Play Console (Usuarios y permisos → «Ver información de la app y descargar informes en masa»
//                                + «Gestionar pedidos y suscripciones»), con la API «Google Play Android Developer» activada
//   PLAY_PACKAGE_NAME            com.srg.dreamracing (si no se pone, se usa ese)
// SUPABASE_URL, SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY los pone Supabase solo.
import { createClient } from 'npm:@supabase/supabase-js@2'
import { googleAccessToken, makeHandler, PRODUCTS, verifyPlayPurchase } from './handler.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const ANON = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const PACKAGE = Deno.env.get('PLAY_PACKAGE_NAME') ?? 'com.srg.dreamracing'

let cached: { token: string; exp: number } | null = null

async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cached && cached.exp > now + 60) return cached.token
  const sa = JSON.parse(Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT') ?? '{}')
  cached = await googleAccessToken(sa, fetch, now)
  return cached.token
}

Deno.serve(makeHandler({
  products: PRODUCTS,
  getUser: async (auth) => {
    if (!auth) return null
    const c = createClient(SUPABASE_URL, ANON, { global: { headers: { Authorization: auth } } })
    const { data, error } = await c.auth.getUser()
    if (error || !data.user || data.user.is_anonymous) return null // sólo cuentas con correo
    return { id: data.user.id }
  },
  verify: async (product, token) => verifyPlayPurchase({ fetchFn: fetch, accessToken: await accessToken(), packageName: PACKAGE, productId: product, token }),
  grant: async (userId, product, hash) => {
    const admin = createClient(SUPABASE_URL, SERVICE)
    const { data, error } = await admin.rpc('account_iap_grant', { p_user: userId, p_product: product, p_token_hash: hash })
    if (error) throw new Error(error.message)
    return data
  },
}))
