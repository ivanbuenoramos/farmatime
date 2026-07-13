// seatPolicy.js
// Única fuente de verdad sobre qué estados de empleado "ocupan plaza" en cada
// contexto. Antes había tres definiciones distintas en tres ficheros, lo que
// provocaba que createEmployeeAccount rechazara altas que billingEmployees
// consideraba que cabían (o al revés).
//
// Contextos:
//   - SEAT_OCCUPYING: estados que CUENTAN como plaza consumida desde el punto
//     de vista de capacity-planning (alta + aviso de cerca-del-límite). Un
//     empleado pendiente de activar la cuenta ya ocupa plaza (la empresa pagó
//     por él).
//   - PROMOTABLE: estados que el cron de morosidad puede mover a active /
//     inactive. Excluimos `pending` porque mientras no acepte la invitación no
//     tiene sentido promocionarlo: se promociona cuando se activa.

// 'deleted' nunca cuenta. Todo lo demás ocupa plaza.
const SEAT_OCCUPYING = new Set(['pending', 'active', 'inactive', 'disabled']);

// Estados elegibles para que billingEmployees decida si quedan active o
// inactive según las plazas disponibles. `pending` queda fuera: aún no es
// promocionable hasta que el empleado active su cuenta.
const PROMOTABLE = new Set(['active', 'inactive', 'disabled']);

function occupiesSeat(accountStatus) {
  return SEAT_OCCUPYING.has(accountStatus);
}

function isPromotable(accountStatus) {
  return PROMOTABLE.has(accountStatus);
}

module.exports = {
  SEAT_OCCUPYING,
  PROMOTABLE,
  occupiesSeat,
  isPromotable,
};
