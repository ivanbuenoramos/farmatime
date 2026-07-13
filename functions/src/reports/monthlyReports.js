const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { v4: uuidv4 } = require('uuid');
const admin = require('firebase-admin');
const PDFDocument = require('pdfkit');
const {
  startOfMonth,
  endOfMonth,
  format,
  parseISO,
} = require('date-fns');
const { sendPushToUsers } = require('../notifications/sendPush');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const storage = admin.storage();

const HOUR_MS = 1000 * 60 * 60;

// ================== HELPERS ==================

function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate(); // Timestamp
  if (typeof value === 'string') return parseISO(value);

  console.error('[reports] Unsupported date type in toDate:', {
    type: typeof value,
    value,
  });
  return null;
}

// Horas de un fichaje. Un fichaje sin salida (abierto) NO suma horas: no
// inventamos una hora de cierre. El día sí se cuenta y los fichajes abiertos se
// reportan aparte (ver openRecordsCount) para que no se pierdan silenciosamente.
function diffHours(clockInISO, clockOutISO) {
  if (!clockOutISO) return 0;
  const a = parseISO(clockInISO);
  const b = parseISO(clockOutISO);
  const ms = Math.max(0, b - a);
  return ms / HOUR_MS;
}

// ID determinístico para que regenerar sobrescriba el mismo doc.
function reportDocId(companyId, employeeId, year, month) {
  const mm = String(month).padStart(2, '0');
  return `${companyId}_${employeeId}_${year}-${mm}`;
}

async function getCompany(companyId) {
  const doc = await db.collection('companies').doc(companyId).get();
  return { id: companyId, ...(doc.data() || {}) };
}

async function getEmployee(employeeId) {
  const doc = await db.collection('employees').doc(employeeId).get();
  if (!doc.exists) return null;
  return { id: employeeId, ...(doc.data() || {}) };
}

async function getEmployees(companyId) {
  const snap = await db
      .collection('employees')
      .where('companyId', '==', companyId)
      .get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

async function getClockRecords(companyId, employeeId, from, to) {
  const start = from instanceof Date ? from : new Date(from);
  const end = to instanceof Date ? to : new Date(to);

  const startTs = admin.firestore.Timestamp.fromDate(start);
  const endTs = admin.firestore.Timestamp.fromDate(end);

  const snap = await db
      .collection('clockRecords')
      .where('companyId', '==', companyId)
      .where('employeeId', '==', employeeId)
      .where('clockIn', '>=', startTs)
      .where('clockIn', '<=', endTs)
      .get();

  const records = [];

  snap.forEach((doc) => {
    const r = doc.data();
    if (!r.clockIn) return;

    const inDate = toDate(r.clockIn);
    const outDate = r.clockOut ? toDate(r.clockOut) : null;

    records.push({
      employeeId,
      companyId,
      clockIn: inDate ? inDate.toISOString() : null,
      clockOut: outDate ? outDate.toISOString() : null,
      notes: r.notes ?? null,
      isEdited: !!r.isEdited,
      editedFields: Array.isArray(r.editedFields) ? r.editedFields : [],
      editedAt: r.editedAt ? toDate(r.editedAt)?.toISOString() : null,
      editedBy: r.editedBy || null,
      editReason: r.editReason || null,
    });
  });

  records.sort((a, b) => (a.clockIn || '').localeCompare(b.clockIn || ''));
  return records;
}

function buildPdf({ company, employee, periodLabel, records }) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 36 });
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    const primaryColor = '#1971FF';

    const companyName =
      company.legalName || company.name || company.companyName || company.id;
    const employeeName = employee.name || employee.fullName || employee.id;

    // ==== CABECERA ====
    doc
        .fontSize(22)
        .fillColor(primaryColor)
        .font('Helvetica-Bold')
        .text('farmatime', { align: 'center' });

    doc.moveDown(0.2);
    doc
        .fontSize(14)
        .fillColor('black')
        .font('Helvetica')
        .text(`Periodo: ${periodLabel}`, { align: 'center' });

    doc.moveDown(0.8);
    doc.moveTo(36, doc.y).lineTo(559, doc.y).stroke();
    doc.moveDown(0.6);

    // ==== BLOQUE EMPRESA ====
    const address = company.address || {};
    const line1 = (address.address || '').trim();
    const line2Parts = [];
    if (address.zipCode) line2Parts.push(address.zipCode);
    if (address.city) line2Parts.push(address.city);
    const line2 = line2Parts.join(' ');
    const line3Parts = [];
    if (address.state) line3Parts.push(address.state);
    if (address.country) line3Parts.push(address.country);
    const line3 = line3Parts.join(', ');

    const vatNumber = company.vatNumber || '';
    const companyEmail = company.email || '';
    const companyPhone = company.phoneNumber || '';

    doc.fontSize(12).font('Helvetica-Bold').text('Datos de la empresa');
    doc.moveDown(0.3);

    const label = (text, value) => {
      doc.font('Helvetica-Bold').text(`${text}: `, { continued: true });
      doc.font('Helvetica').text(value || '');
    };

    label('Razón social', companyName);
    if (vatNumber) label('NIF/CIF', vatNumber);
    if (line1) label('Dirección', line1);
    if (line2) label('Localidad', line2);
    if (line3) label('Provincia / País', line3);
    if (companyEmail) label('Email', companyEmail);
    if (companyPhone) label('Teléfono', companyPhone);

    doc.moveDown(0.6);
    doc.moveTo(36, doc.y).lineTo(559, doc.y).stroke();
    doc.moveDown(0.6);

    // ==== BLOQUE EMPLEADO ====
    doc.fontSize(12).font('Helvetica-Bold').text('Datos del empleado');
    doc.moveDown(0.3);

    label('Nombre', employeeName);
    if (employee.workdayType) label('Tipo de jornada', employee.workdayType);

    doc.moveDown(0.6);
    doc.moveTo(36, doc.y).lineTo(559, doc.y).stroke();
    doc.moveDown(0.6);

    // ==== TABLA DE FICHAJES AGRUPADA POR DÍA ====
    doc.fontSize(12).font('Helvetica-Bold').text('Detalle de fichajes');
    doc.moveDown(0.3);

    if (!records.length) {
      doc.font('Helvetica').fontSize(10).text('No hay fichajes en el periodo.');
      doc.end();
      return;
    }

    // Agrupar por fecha (día)
    const groupedByDate = {};
    let totalHours = 0;
    let daysCount = 0;

    for (const r of records) {
      const d = parseISO(r.clockIn);
      const key = format(d, 'yyyy-MM-dd');
      if (!groupedByDate[key]) groupedByDate[key] = [];
      groupedByDate[key].push(r);

      const h = diffHours(r.clockIn, r.clockOut);
      if (h > 0) {
        totalHours += h;
      }
    }

    daysCount = Object.keys(groupedByDate).length;

    const sortedDates = Object.keys(groupedByDate).sort();

    const ensureSpace = (extra = 40) => {
      if (doc.y + extra > doc.page.height - doc.page.margins.bottom) {
        doc.addPage();
      }
    };

    for (const dateKey of sortedDates) {
      const dayRecords = groupedByDate[dateKey];
      const dateLabel = format(parseISO(dayRecords[0].clockIn), 'dd/MM/yyyy');

      ensureSpace(60);
      doc
          .font('Helvetica-Bold')
          .fontSize(11)
          .fillColor(primaryColor)
          .text(dateLabel);
      doc.fillColor('black');
      doc.moveDown(0.1);

      // Cabecera de columnas
      doc.fontSize(9).font('Helvetica-Bold');
      doc.text('Entrada', 40, doc.y, { continued: true });
      doc.text('Salida', 110, doc.y, { continued: true });
      doc.text('Horas', 180, doc.y, { continued: true });
      doc.text('Notas', 240, doc.y, { continued: true });
      doc.text('Editado', 450, doc.y);
      doc.moveDown(0.1);
      doc.moveTo(36, doc.y).lineTo(559, doc.y).stroke();

      doc.moveDown(0.1);
      doc.font('Helvetica').fontSize(9);

      for (const r of dayRecords) {
        ensureSpace(30);

        const hi = r.clockIn ? format(parseISO(r.clockIn), 'HH:mm') : '--:--';
        const ho = r.clockOut ? format(parseISO(r.clockOut), 'HH:mm') : '--:--';
        const h = diffHours(r.clockIn, r.clockOut);
        const hoursLabel = h > 0 ? h.toFixed(2) : '-';
        const editedLabel = r.isEdited ? 'Sí' : 'No';

        const rowY = doc.y;

        doc.text(hi, 40, rowY, { continued: true });
        doc.text(ho, 110, rowY, { continued: true });
        doc.text(hoursLabel, 180, rowY, { continued: true });
        doc.text(r.notes || '', 240, rowY, {
          continued: true,
          width: 200,
        });
        doc.text(editedLabel, 450, rowY);

        doc.moveDown(0.2);
      }

      doc.moveDown(0.2);
    }

    // Resumen
    doc.moveDown(0.4);
    doc.moveTo(36, doc.y).lineTo(559, doc.y).stroke();
    doc.moveDown(0.3);
    doc
        .fontSize(11)
        .font('Helvetica-Bold')
        .text(
            `Total días con fichaje: ${daysCount}    Total horas: ${totalHours.toFixed(
                2,
            )}`,
            { align: 'right' },
        );

    // ==== SECCIÓN DE EDICIONES ====
    const editedRecords = records.filter((r) => r.isEdited);

    if (editedRecords.length) {
      doc.addPage();
      doc.fontSize(12).font('Helvetica-Bold').fillColor(primaryColor);
      doc.text('Historial de ediciones de fichajes');
      doc.fillColor('black');
      doc.moveDown(0.3);

      const editsByDate = {};
      for (const r of editedRecords) {
        const key = format(parseISO(r.clockIn), 'yyyy-MM-dd');
        if (!editsByDate[key]) editsByDate[key] = [];
        editsByDate[key].push(r);
      }
      const editDates = Object.keys(editsByDate).sort();

      doc.fontSize(10).font('Helvetica');

      for (const dateKey of editDates) {
        ensureSpace(60);
        const dateLabel = format(parseISO(dateKey), 'dd/MM/yyyy');
        doc.font('Helvetica-Bold').text(dateLabel);
        doc.font('Helvetica');
        doc.moveDown(0.1);

        const dayEdits = editsByDate[dateKey];

        dayEdits.forEach((r) => {
          ensureSpace(50);
          const hi = r.clockIn ? format(parseISO(r.clockIn), 'HH:mm') : '--:--';
          const ho = r.clockOut ? format(parseISO(r.clockOut), 'HH:mm') : '--:--';
          const editedAtLabel = r.editedAt ?
            format(parseISO(r.editedAt), 'dd/MM/yyyy HH:mm') :
            '-';
          const editedBy = r.editedBy || '-';
          const fields = r.editedFields && r.editedFields.length ?
            r.editedFields.join(', ') :
            '-';
          const reason = r.editReason || '-';

          doc.text(
              `• Fichaje ${hi} - ${ho} | Campos editados: ${fields}`,
              { width: 520 },
          );
          doc.text(`  Editado por: ${editedBy}`);
          doc.text(`  Fecha edición: ${editedAtLabel}`);
          doc.text(`  Motivo: ${reason}`);
          doc.moveDown(0.4);
        });

        doc.moveDown(0.2);
      }
    }

    doc.end();
  });
}

async function uploadPdf({
  companyId,
  employeeId,
  periodStart,
  periodEnd,
  buffer,
}) {
  const startLabel = format(periodStart, 'yyyy-MM-dd');
  const endLabel = format(periodEnd, 'yyyy-MM-dd');
  const path = `reports/${companyId}/${employeeId}/${startLabel}_${endLabel}.pdf`;

  const bucket = storage.bucket();
  const file = bucket.file(path);

  // Si ya existe, reutilizamos el mismo download token para no invalidar URLs.
  let downloadToken = uuidv4();
  try {
    const [meta] = await file.getMetadata();
    const existingToken =
      meta && meta.metadata && meta.metadata.firebaseStorageDownloadTokens;
    if (existingToken) {
      downloadToken = String(existingToken).split(',')[0];
    }
  } catch (_) {
    // El archivo no existe aún; usamos el token nuevo.
  }

  await file.save(buffer, {
    contentType: 'application/pdf',
    resumable: false,
    metadata: {
      cacheControl: 'public, max-age=3600',
      metadata: {
        firebaseStorageDownloadTokens: downloadToken,
      },
    },
  });

  const encodedPath = encodeURIComponent(path);
  const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media&token=${downloadToken}`;

  return { path, url };
}

async function upsertClockReportDoc({
  companyId,
  employeeId,
  year,
  month,
  periodStart,
  periodEnd,
  pdfPath,
  downloadUrl,
  totalHours,
  daysCount,
  recordsCount,
  openRecordsCount = 0,
  source,
}) {
  const id = reportDocId(companyId, employeeId, year, month);
  await db
      .collection('clockReports')
      .doc(id)
      .set(
          {
            companyId,
            employeeId,
            year,
            month,
            periodStart: periodStart.toISOString(),
            periodEnd: periodEnd.toISOString(),
            pdfPath,
            downloadUrl,
            totalHours,
            daysCount,
            recordsCount,
            // Fichajes sin salida en el periodo: sus horas no se suman a
            // totalHours; sirve para alertar de registros incompletos.
            openRecordsCount,
            source,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
      );
}

/**
 * Genera (o regenera) el PDF de un empleado para un mes concreto.
 * Es idempotente: sobrescribe el PDF y el doc en `clockReports`.
 *
 * @param {Object} args
 * @param {string} args.companyId
 * @param {string} args.employeeId
 * @param {number} args.year
 * @param {number} args.month  1-12
 * @param {string} args.source  'auto_monthly' | 'auto_trigger' | 'manual'
 * @param {Object} [args.companyOverride] Para evitar re-leer la empresa.
 * @param {Object} [args.employeeOverride] Para evitar re-leer el empleado.
 */
async function generateForEmployeeMonth({
  companyId,
  employeeId,
  year,
  month,
  source,
  companyOverride,
  employeeOverride,
}) {
  const periodStart = startOfMonth(new Date(year, month - 1, 1));
  const periodEnd = endOfMonth(periodStart);

  const company = companyOverride || (await getCompany(companyId));
  const employee = employeeOverride || (await getEmployee(employeeId));
  if (!employee) {
    console.warn('[reports] empleado no existe, se omite', { employeeId });
    return null;
  }

  const records = await getClockRecords(
      companyId,
      employeeId,
      periodStart,
      periodEnd,
  );

  const totalHours = records.reduce(
      (acc, r) => acc + diffHours(r.clockIn, r.clockOut),
      0,
  );
  // daysCount = días distintos con AL MENOS UN fichaje (abierto o cerrado), igual
  // que en el PDF. Antes solo contaba días con salida, lo que perdía el último
  // día si el fichaje quedaba abierto.
  const workedDays = new Set();
  let openRecordsCount = 0;
  for (const r of records) {
    workedDays.add(format(parseISO(r.clockIn), 'yyyy-MM-dd'));
    if (!r.clockOut) openRecordsCount += 1;
  }
  const daysCount = workedDays.size;

  const periodLabel = `${format(periodStart, 'dd/MM/yyyy')} - ${format(
      periodEnd,
      'dd/MM/yyyy',
  )}`;

  const pdfBuffer = await buildPdf({
    company,
    employee,
    periodLabel,
    records,
  });

  const { path, url } = await uploadPdf({
    companyId,
    employeeId,
    periodStart,
    periodEnd,
    buffer: pdfBuffer,
  });

  await upsertClockReportDoc({
    companyId,
    employeeId,
    year,
    month,
    periodStart,
    periodEnd,
    pdfPath: path,
    downloadUrl: url,
    totalHours,
    daysCount,
    recordsCount: records.length,
    openRecordsCount,
    source,
  });

  console.log('[reports] generado', {
    companyId,
    employeeId,
    year,
    month,
    recordsCount: records.length,
    source,
  });

  return { companyId, employeeId, year, month, recordsCount: records.length };
}

async function generateForCompanyMonth({
  companyId,
  year,
  month,
  source,
  onlyWithRecords = false,
}) {
  const company = await getCompany(companyId);
  const employees = await getEmployees(companyId);

  let generated = 0;
  const generatedEmployeeIds = [];
  for (const emp of employees) {
    // eslint-disable-next-line no-await-in-loop
    const periodStart = startOfMonth(new Date(year, month - 1, 1));
    const periodEnd = endOfMonth(periodStart);
    // eslint-disable-next-line no-await-in-loop
    const records = await getClockRecords(
        companyId,
        emp.id,
        periodStart,
        periodEnd,
    );
    if (onlyWithRecords && !records.length) continue;
    // Empleados borrados: solo conservamos el reporte del mes en el que SÍ
    // trabajaron (dato laboral legítimo). No generamos reportes vacíos de meses
    // posteriores a su baja (privacidad / minimización de datos).
    if (emp.accountStatus === 'deleted' && !records.length) continue;

    // eslint-disable-next-line no-await-in-loop
    await generateForEmployeeMonth({
      companyId,
      employeeId: emp.id,
      year,
      month,
      source,
      companyOverride: company,
      employeeOverride: emp,
    });
    generated += 1;
    if (emp.accountStatus !== 'deleted') generatedEmployeeIds.push(emp.id);
  }

  return { companyId, year, month, generated, source, generatedEmployeeIds };
}

// ============ EXPORTS ============

// 1) Programada: día 1 de cada mes a la 01:00 → genera mes anterior completo.
const reportsScheduleMonthly = onSchedule(
    { schedule: '0 1 1 * *', timeZone: 'Europe/Madrid' },
    async () => {
      const companies = await db
          .collection('companies')
          .where('billingStatus', '==', 'active')
          .get();

      const ref = new Date();
      ref.setDate(1);
      ref.setMonth(ref.getMonth() - 1);
      const year = ref.getFullYear();
      const month = ref.getMonth() + 1;

      const monthLabel = format(ref, 'MM/yyyy');

      for (const c of companies.docs) {
        // eslint-disable-next-line no-await-in-loop
        const res = await generateForCompanyMonth({
          companyId: c.id,
          year,
          month,
          source: 'auto_monthly',
          onlyWithRecords: false,
        });

        // Notifica a la empresa y a sus empleados que el reporte está listo.
        try {
          // eslint-disable-next-line no-await-in-loop
          await sendPushToUsers({
            uids: [c.id],
            title: 'Reportes mensuales listos',
            body: `Los reportes de horas de ${monthLabel} ya están disponibles`,
            data: { type: 'report_ready', month: monthLabel },
          });
          const empIds = (res && res.generatedEmployeeIds) || [];
          if (empIds.length) {
            // eslint-disable-next-line no-await-in-loop
            await sendPushToUsers({
              uids: empIds,
              title: 'Tu reporte de horas está listo',
              body: `Ya puedes consultar tu reporte de ${monthLabel}`,
              data: { type: 'report_ready', month: monthLabel },
            });
          }
        } catch (e) {
          console.warn('[reports] error notificando reporte listo', e);
        }
      }
    },
);

// 2) Manual: regenera el mes actual hasta hoy (sigue disponible por compatibilidad).
const reportsGenerateRange = onCall(async (request) => {
  try {
    const data = request.data || {};
    const companyId = data.companyId;
    const startStr = data.startDate;
    const endStr = data.endDate;

    if (!companyId || !startStr || !endStr) {
      throw new HttpsError(
          'invalid-argument',
          'companyId, startDate y endDate son requeridos',
      );
    }

    const periodStart = new Date(startStr);
    const periodEnd = new Date(endStr);

    if (
      Number.isNaN(periodStart.getTime()) ||
      Number.isNaN(periodEnd.getTime())
    ) {
      throw new HttpsError('invalid-argument', 'Fechas inválidas');
    }

    if (
      periodStart.getFullYear() !== periodEnd.getFullYear() ||
      periodStart.getMonth() !== periodEnd.getMonth()
    ) {
      throw new HttpsError(
          'invalid-argument',
          'startDate y endDate deben pertenecer al mismo mes y año',
      );
    }

    return await generateForCompanyMonth({
      companyId,
      year: periodStart.getFullYear(),
      month: periodStart.getMonth() + 1,
      source: 'manual',
      onlyWithRecords: false,
    });
  } catch (err) {
    console.error('[reportsGenerateRange] error', err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError(
        'internal',
        err.message || 'Error generando reportes',
    );
  }
});

// 3) Trigger: cuando se crea/edita/borra un fichaje, regenera el PDF
//    del empleado para el mes afectado.
//    - Idempotente (mismo doc/path se sobrescribe).
//    - Si la edición mueve el fichaje a otro mes, regenera ambos meses.
const reportsOnClockRecordWrite = onDocumentWritten(
    {
      document: 'clockRecords/{recordId}',
      // Limitamos concurrencia para no saturar el bucket en ediciones masivas.
      concurrency: 5,
    },
    async (event) => {
      const before = event.data && event.data.before && event.data.before.exists ?
        event.data.before.data() : null;
      const after = event.data && event.data.after && event.data.after.exists ?
        event.data.after.data() : null;

      const source = after || before;
      if (!source) return;

      const companyId = source.companyId;
      const employeeId = source.employeeId;
      if (!companyId || !employeeId) {
        console.warn('[reports] trigger sin companyId/employeeId, skip');
        return;
      }

      // Conjunto de (year, month) afectados (puede ser 1 o 2).
      const affected = new Set();
      const addFrom = (data) => {
        if (!data || !data.clockIn) return;
        const d = toDate(data.clockIn);
        if (!d) return;
        affected.add(`${d.getFullYear()}-${d.getMonth() + 1}`);
      };
      addFrom(before);
      addFrom(after);

      if (!affected.size) return;

      const company = await getCompany(companyId);
      const employee = await getEmployee(employeeId);
      if (!employee) return;

      for (const key of affected) {
        const [yStr, mStr] = key.split('-');
        // eslint-disable-next-line no-await-in-loop
        await generateForEmployeeMonth({
          companyId,
          employeeId,
          year: Number(yStr),
          month: Number(mStr),
          source: 'auto_trigger',
          companyOverride: company,
          employeeOverride: employee,
        });
      }
    },
);

module.exports = {
  reportsScheduleMonthly,
  reportsGenerateRange,
  reportsOnClockRecordWrite,
};
