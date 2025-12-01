const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { v4: uuidv4 } = require('uuid');
const admin = require('firebase-admin');
const PDFDocument = require('pdfkit');
const {
  startOfMonth,
  endOfMonth,
  format,
  parseISO,
  isWithinInterval,
} = require('date-fns');

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
  return null; // mejor saltar el registro que reventar toda la función
}

function diffHours(clockInISO, clockOutISO) {
  if (!clockOutISO) return 0;
  const a = parseISO(clockInISO);
  const b = parseISO(clockOutISO);
  const ms = Math.max(0, b - a);
  return ms / HOUR_MS;
}

async function getCompany(companyId) {
  const doc = await db.collection('companies').doc(companyId).get();
  return { id: companyId, ...(doc.data() || {}) };
}

async function getEmployees(companyId) {
  const snap = await db
      .collection('employees')
      .where('companyId', '==', companyId)
      // .where('accountStatus', '==', 'active')
      .get();

  console.log('[reports] empleados encontrados para company', companyId, snap.size);

  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

async function getClockRecords(companyId, employeeId, from, to) {
  const snap = await db
      .collection('clockRecords')
      .where('companyId', '==', companyId)
      .where('employeeId', '==', employeeId)
      .get();

  const interval = { start: from, end: to };
  const records = [];

  snap.forEach((doc) => {
    const r = doc.data();
    if (!r.clockIn) return;

    const inDate = toDate(r.clockIn);
    if (!inDate) return;

    if (isWithinInterval(inDate, interval)) {
      const outDate = r.clockOut ? toDate(r.clockOut) : null;

      records.push({
        employeeId,
        companyId,
        clockIn: inDate.toISOString(), // normalizamos a ISO string
        clockOut: outDate ? outDate.toISOString() : null,
        notes: r.notes ?? null,
      });
    }
  });

  records.sort((a, b) => a.clockIn.localeCompare(b.clockIn));
  return records;
}

function buildPdf({ companyName, employeeName, periodLabel, records }) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 36 });
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    doc.fontSize(16).text('Reporte de fichajes', { align: 'center' });
    doc.moveDown(0.5);
    doc.fontSize(11).text(`Empresa: ${companyName}`);
    doc.text(`Empleado: ${employeeName}`);
    doc.text(`Periodo: ${periodLabel}`);
    doc.moveDown();

    doc
        .fontSize(11)
        .text('Fecha         Entrada   Salida    Horas     Notas');
    doc.moveTo(36, doc.y).lineTo(559, doc.y).stroke();

    let totalHours = 0;
    let days = 0;

    for (const r of records) {
      const d = parseISO(r.clockIn);
      const dateStr = format(d, 'yyyy-MM-dd');
      const hi = r.clockIn ? format(parseISO(r.clockIn), 'HH:mm') : '--:--';
      const ho = r.clockOut ? format(parseISO(r.clockOut), 'HH:mm') : '--:--';
      const h = diffHours(r.clockIn, r.clockOut);

      if (h > 0) {
        totalHours += h;
        days += 1;
      }

      doc.moveDown(0.2);
      doc.text(
          `${dateStr}     ${hi}      ${ho}      ${h.toFixed(2)}      ${
            r.notes || ''
          }`,
          { width: 520 },
      );
      if (doc.y > 760) doc.addPage();
    }

    doc.moveDown();
    doc.moveTo(36, doc.y).lineTo(559, doc.y).stroke();
    doc.moveDown(0.3);
    doc.fontSize(12).text(
        `Total días: ${days}    Total horas: ${totalHours.toFixed(2)}`,
        { align: 'right' },
    );

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

  // Token de descarga tipo Firebase Storage
  const downloadToken = uuidv4();

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

async function saveClockReportDoc({
  companyId,
  employeeId,
  periodStart,
  periodEnd,
  pdfPath,
  downloadUrl,
  totalHours,
  daysCount,
  source,
}) {
  await db.collection('clockReports').add({
    companyId,
    employeeId,
    periodStart: periodStart.toISOString(),
    periodEnd: periodEnd.toISOString(),
    pdfPath,
    downloadUrl,
    totalHours,
    daysCount,
    source, // 'auto_monthly' o 'manual'
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function generateForCompanyRange(
    companyId,
    periodStart,
    periodEnd,
    source,
) {
  console.log('[reports] start generateForCompanyRange', {
    companyId,
    periodStart: periodStart.toISOString(),
    periodEnd: periodEnd.toISOString(),
    source,
  });

  const company = await getCompany(companyId);
  console.log('[reports] company doc:', company);

  const employees = await getEmployees(companyId);
  console.log('[reports] total empleados:', employees.length);

  const periodLabel = `${format(periodStart, 'yyyy-MM-dd')} - ${
    format(periodEnd, 'yyyy-MM-dd')
  }`;

  let generated = 0;

  for (const emp of employees) {
    console.log('[reports] procesando empleado', emp.id);
    const records = await getClockRecords(
        companyId,
        emp.id,
        periodStart,
        periodEnd,
    );
    console.log('[reports] registros de', emp.id, ':', records.length);

    if (!records.length) continue;

    const totalHours = records.reduce(
        (acc, r) => acc + diffHours(r.clockIn, r.clockOut),
        0,
    );
    const daysCount = records.filter((r) => r.clockOut).length;

    const pdfBuffer = await buildPdf({
      companyName: company.name || companyId,
      employeeName: emp.name || emp.id,
      periodLabel,
      records,
    });

    const { path, url } = await uploadPdf({
      companyId,
      employeeId: emp.id,
      periodStart,
      periodEnd,
      buffer: pdfBuffer,
    });

    console.log('[reports] PDF creado', { employeeId: emp.id, path, url });

    await saveClockReportDoc({
      companyId,
      employeeId: emp.id,
      periodStart,
      periodEnd,
      pdfPath: path,
      downloadUrl: url,
      totalHours,
      daysCount,
      source,
    });

    generated += 1;
  }

  console.log('[reports] finished generateForCompanyRange', {
    companyId,
    generated,
  });

  return {
    companyId,
    periodStart: periodStart.toISOString(),
    periodEnd: periodEnd.toISOString(),
    generated,
    source,
  };
}

// ============ EXPORTS ============

// 1) Programada: día 1, mes anterior completo.
const reportsScheduleMonthly = onSchedule(
    { schedule: '0 1 1 * *', timeZone: 'Europe/Madrid' },
    async () => {
      const companies = await db
          .collection('companies')
          .where('billingStatus', '==', 'active')
          .get();

      const now = new Date();
      now.setMonth(now.getMonth() - 1);
      const periodStart = startOfMonth(now);
      const periodEnd = endOfMonth(now);

      for (const c of companies.docs) {
        // eslint-disable-next-line no-await-in-loop
        await generateForCompanyRange(
            c.id,
            periodStart,
            periodEnd,
            'auto_monthly',
        );
      }
    },
);

// 2) Manual: rango dentro del mismo mes (CALLABLE)
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

    if (periodStart > periodEnd) {
      throw new HttpsError(
          'invalid-argument',
          'startDate no puede ser posterior a endDate',
      );
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

    const result = await generateForCompanyRange(
        companyId,
        periodStart,
        periodEnd,
        'manual',
    );

    return result;
  } catch (err) {
    console.error('[reportsGenerateRange] error', err);
    if (err instanceof HttpsError) {
      throw err;
    }
    throw new HttpsError(
        'internal',
        err.message || 'Error generando reportes',
    );
  }
});

module.exports = {
  reportsScheduleMonthly,
  reportsGenerateRange,
};
