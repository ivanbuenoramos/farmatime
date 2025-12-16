const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { db } = require('../config/firebase');
const { assertAuth, assertCompanyAccount } = require('../helpers/assertions');
const { updateCompanyMirror } = require('../helpers/companyMirror');
const { updateEmployeesForBillingState } = require('../helpers/billingEmployees');
const { getStripe } = require('../config/stripe');

exports.stripe_applySeatChange = onCall(async (request) => {
  try {
    assertAuth(request);
    const uid = String(request.auth.uid || '').trim();
    const data = request.data || {};

    const companyId = String(data.companyId || '').trim();
    const newTotalSeats = Number(data.newTotalSeats || 1);

    if (!companyId) throw new HttpsError('invalid-argument', 'companyId requerido');
    if (!Number.isInteger(newTotalSeats) || newTotalSeats < 1) {
      throw new HttpsError('invalid-argument', 'newTotalSeats inválido');
    }

    await assertCompanyAccount(uid, companyId);

    const companySnap = await db.collection('companies').doc(companyId).get();
    if (!companySnap.exists) throw new HttpsError('not-found', 'Empresa no existe');

    const company = companySnap.data() || {};
    const customerId = String(company.stripeCustomerId || '').trim();
    const subscriptionId = String(company.stripeSubscriptionId || '').trim();
    // const currentPeriodEnd = company.currentPeriodEnd || null;

    if (!customerId) throw new HttpsError('failed-precondition', 'No hay cliente Stripe asociado');

    const PRICE_ID = process.env.PRICE_ID;
    if (!PRICE_ID) throw new HttpsError('failed-precondition', 'PRICE_ID no configurado');

    const stripe = getStripe();
    const newPaidSeats = Math.max(newTotalSeats - 1, 0);

    // ✅ BAJADA A 1 (gratis): cancela suscripción y aplica ya
    if (newPaidSeats === 0) {
      if (subscriptionId) {
        try {
          await stripe.subscriptions.cancel(subscriptionId);
        } catch (_) {
          // ignorar errores de cancelación
        }
      }

      await updateCompanyMirror(companyId, {
        stripeSubscriptionId: null,
        billingStatus: 'none',
        contractedSeats: 1,
        pendingSeats: null,
        currentPeriodEnd: null,

        // limpieza de programados
        scheduledSeats: null,
        scheduledPaidSeats: null,
        scheduledForPeriodEnd: null,
      });

      await updateEmployeesForBillingState(companyId);

      return { ok: true, applied: true, newTotalSeats: 1, chargedNow: false };
    }

    // Si NO hay suscripción: crear y cobrar off-session
    if (!subscriptionId) {
      const created = await stripe.subscriptions.create({
        customer: customerId,
        items: [{ price: PRICE_ID, quantity: newPaidSeats }],
        collection_method: 'charge_automatically',
        payment_behavior: 'default_incomplete',
        proration_behavior: 'create_prorations',
        metadata: { companyId },
        expand: ['latest_invoice.payment_intent'],
      });

      const inv = created.latest_invoice || null;
      const pi = inv?.payment_intent || null;

      // Intento de cobro off-session si hay PI
      if (pi?.id && inv?.id) {
        try {
          const paid = await stripe.invoices.pay(inv.id, { off_session: true });
          // Si pagó, confirmamos plazas
          if (paid.status === 'paid') {
            await updateCompanyMirror(companyId, {
              stripeSubscriptionId: created.id,
              billingStatus: 'active',
              contractedSeats: newTotalSeats,
              pendingSeats: null,
              currentPeriodEnd: created.current_period_end,
            });
            await updateEmployeesForBillingState(companyId);
            return { ok: true, applied: true, newTotalSeats, chargedNow: true };
          }
        } catch (e) {
          // Si requiere acción (3DS), devolvemos client_secret para PaymentSheet fallback
          const code = e?.code || '';
          const msg = e?.message || String(e);
          logger.warn('[applySeatChange] pay off_session failed', { code, msg });

          await updateCompanyMirror(companyId, {
            stripeSubscriptionId: created.id,
            billingStatus: created.status,
            pendingSeats: newTotalSeats,
            currentPeriodEnd: created.current_period_end,
          });

          return {
            ok: true,
            applied: false,
            requiresAction: true,
            paymentIntentClientSecret: pi?.client_secret || null,
            subscriptionId: created.id,
            invoiceId: inv?.id || null,
          };
        }
      }

      // Si no hay invoice/PI o no se pudo pagar: lo dejamos pendiente (pero NO confirmamos contractedSeats)
      await updateCompanyMirror(companyId, {
        stripeSubscriptionId: created.id,
        billingStatus: created.status,
        pendingSeats: newTotalSeats,
        currentPeriodEnd: created.current_period_end,
      });

      return {
        ok: true,
        applied: false,
        requiresAction: true,
        paymentIntentClientSecret: pi?.client_secret || null,
        subscriptionId: created.id,
        invoiceId: inv?.id || null,
      };
    }

    // Si hay suscripción: vemos si es subida o bajada
    const sub = await stripe.subscriptions.retrieve(subscriptionId, { expand: ['items.data'] });
    const item = sub?.items?.data?.[0];
    if (!item?.id) throw new HttpsError('internal', 'No se encontró el item de suscripción');

    const currentPaidSeats = typeof item.quantity === 'number' ? item.quantity : 0;
    const isIncrease = newPaidSeats > currentPaidSeats;

    // ✅ SUBIR: prorrateo inmediato + cobro obligatorio (off-session primero; fallback si SCA)
    if (isIncrease) {
      const updated = await stripe.subscriptions.update(subscriptionId, {
        payment_behavior: 'default_incomplete',
        proration_behavior: 'create_prorations',
        items: [{ id: item.id, quantity: newPaidSeats }],
        expand: ['latest_invoice.payment_intent'],
      });

      const inv = updated.latest_invoice || null;
      const pi = inv?.payment_intent || null;

      if (inv?.id) {
        try {
          const paid = await stripe.invoices.pay(inv.id, { off_session: true });
          if (paid.status === 'paid') {
            await updateCompanyMirror(companyId, {
              billingStatus: 'active',
              contractedSeats: newTotalSeats,
              pendingSeats: null,
              currentPeriodEnd: updated.current_period_end,
            });
            await updateEmployeesForBillingState(companyId);
            return { ok: true, applied: true, newTotalSeats, chargedNow: true };
          }
        } catch (e) {
          await updateCompanyMirror(companyId, {
            billingStatus: updated.status,
            pendingSeats: newTotalSeats,
            currentPeriodEnd: updated.current_period_end,
          });

          return {
            ok: true,
            applied: false,
            requiresAction: true,
            paymentIntentClientSecret: pi?.client_secret || null,
            subscriptionId,
            invoiceId: inv?.id || null,
          };
        }
      }

      // Sin invoice (raro): confirmamos
      await updateCompanyMirror(companyId, {
        billingStatus: updated.status,
        contractedSeats: newTotalSeats,
        pendingSeats: null,
        currentPeriodEnd: updated.current_period_end,
      });
      await updateEmployeesForBillingState(companyId);
      return { ok: true, applied: true, newTotalSeats, chargedNow: false };
    }

    // ✅ BAJAR: sin prorrateo, NO tocamos Stripe ahora.
    // Programamos el cambio para el final del periodo (y podemos desactivar empleados ya si quieres)
    // Nota: currentPeriodEnd en Firestore lo guardas como Timestamp (tu mirror lo hace)
    const periodEndUnix = updatedPeriodEndUnix(sub); // helper debajo
    if (!periodEndUnix) {
      throw new HttpsError('failed-precondition', 'No se pudo determinar current_period_end');
    }

    await updateCompanyMirror(companyId, {
      // NO tocamos contractedSeats aquí (facturación actual se mantiene)
      scheduledSeats: newTotalSeats,
      scheduledPaidSeats: newPaidSeats,
      scheduledForPeriodEnd: periodEndUnix,
    });

    // Aquí SÍ puedes forzar que el acceso se reduzca ya (desactivando empleados) aunque se siga pagando este ciclo:
    await updateEmployeesForBillingState(companyId, { overrideAllowedActive: newTotalSeats });

    return { ok: true, applied: false, scheduled: true, newTotalSeats, effectiveNow: true };
  } catch (err) {
    logger.error('[stripe_applySeatChange] FAILED', { msg: err?.message || String(err), stack: err?.stack || null });
    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', err?.message || 'Error interno');
  }
});

function updatedPeriodEndUnix(sub) {
  // Stripe devuelve current_period_end en unix seconds
  const v = sub?.current_period_end;
  return typeof v === 'number' ? v : null;
}
