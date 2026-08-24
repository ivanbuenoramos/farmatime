#!/usr/bin/env node
/**
 * Verifica contra la Play Developer API que las suscripciones están bien
 * montadas y que la service account tiene acceso real a Play Console.
 *
 * Comprueba exactamente lo que hizo fallar el primer intento: que los product
 * IDs existan tal cual los pide el cliente y que cada uno tenga al menos un
 * base plan ACTIVO (un base plan en DRAFT hace que queryProductDetails los
 * devuelva en notFoundIDs con error null, sin ninguna pista del motivo).
 *
 * Uso, desde la raíz del repo:
 *
 *   gcloud secrets versions access latest \
 *     --secret=GOOGLE_PLAY_SERVICE_ACCOUNT --project=farmatime-app \
 *     > /tmp/play-sa.json
 *   GOOGLE_PLAY_SERVICE_ACCOUNT="$(cat /tmp/play-sa.json)" \
 *     node docs/play-store/verify-play-setup.js
 *   rm -f /tmp/play-sa.json
 */
const path = require('path');
const { GoogleAuth } = require(path.join(__dirname, '../../functions/node_modules/google-auth-library'));
const { google } = require(path.join(__dirname, '../../functions/node_modules/googleapis'));

const PACKAGE = 'net.farmatime.app';
const EXPECTED = ['plan_5_employees', 'plan_10_employees', 'plan_20_employees'];

(async () => {
  const raw = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT;
  if (!raw) {
    console.error('Falta GOOGLE_PLAY_SERVICE_ACCOUNT. Mira las instrucciones de la cabecera.');
    process.exit(1);
  }

  let credentials;
  try {
    credentials = JSON.parse(raw);
  } catch (e) {
    console.error('GOOGLE_PLAY_SERVICE_ACCOUNT no es JSON valido.');
    process.exit(1);
  }
  console.log(`Service account: ${credentials.client_email}\n`);

  const auth = new GoogleAuth({
    credentials,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const publisher = google.androidpublisher({ version: 'v3', auth });

  let subs;
  try {
    const res = await publisher.monetization.subscriptions.list({
      packageName: PACKAGE,
      pageSize: 50,
    });
    subs = res.data.subscriptions || [];
  } catch (e) {
    const status = e?.code || e?.response?.status;
    console.error(`ERROR al listar suscripciones (HTTP ${status}): ${e.message}\n`);
    if (status === 401 || status === 403) {
      console.error('Suele significar una de estas tres cosas:');
      console.error('  - La SA no esta invitada en Play Console -> Usuarios y permisos.');
      console.error('  - Le faltan los permisos de ver datos financieros / gestionar pedidos.');
      console.error('  - Los permisos aun no han propagado (tarda hasta 24-48h).');
    }
    process.exit(1);
  }

  console.log(`La API responde: ${subs.length} suscripcion(es) en ${PACKAGE}.`);
  console.log('Acceso de la service account a Play Console: OK\n');

  let ok = true;
  for (const id of EXPECTED) {
    const sub = subs.find((s) => s.productId === id);
    if (!sub) {
      console.log(`  [FALTA]  ${id} -- no existe en Play Console`);
      ok = false;
      continue;
    }
    const plans = sub.basePlans || [];
    const active = plans.filter((p) => p.state === 'ACTIVE');
    if (!active.length) {
      const estados = plans.map((p) => `${p.basePlanId}=${p.state}`).join(', ') || 'ninguno';
      console.log(`  [DRAFT]  ${id} -- existe pero sin base plan ACTIVO (${estados})`);
      ok = false;
      continue;
    }
    const detalle = active
      .map((p) => `${p.basePlanId} ${p.autoRenewingBasePlanType ? 'auto-renovable' : 'prepago'}`)
      .join(', ');
    console.log(`  [OK]     ${id} -- ${detalle}`);
  }

  const extra = subs.filter((s) => !EXPECTED.includes(s.productId));
  if (extra.length) {
    console.log('\nSuscripciones no usadas por la app (candidatas a archivar):');
    for (const s of extra) {
      const estados = (s.basePlans || []).map((p) => `${p.basePlanId}=${p.state}`).join(', ');
      console.log(`  - ${s.productId}${estados ? ` (${estados})` : ''}`);
    }
  }

  console.log(ok
    ? '\nTodo correcto: la app deberia encontrar los tres productos.'
    : '\nHay problemas: queryProductDetails devolvera notFoundIDs hasta arreglarlos.');
  process.exit(ok ? 0 : 1);
})();
