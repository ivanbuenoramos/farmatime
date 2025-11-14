const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2/options');
const admin = require('firebase-admin');
const PDFDocument = require('pdfkit');
const sg = require('@sendgrid/mail');
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

setGlobalOptions({
  region: 'europe-west1',
  memory: '1GiB',
  timeoutSeconds: 540,
});

const HOUR_MS = 1000 * 60 * 60;

function yyyyMM(d) {
  return format(d, 'yyyy-MM');
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

async function getCompanyEmails(company) {
  const emails = [];
  if (company.email) emails.push(company.email);
  if (Array.isArray(company.billingEmails)) {
    emails.push(...company.billingEmails);
  }
  return emails.filter(Boolean);
}

async function getEmployees(companyId) {
  const snap = await db
      .collection('employees')
      .where('companyId', '==', companyId)
      .where('isActive', '==', true)
      .get();

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
    const inD = parseISO(r.clockIn);
    if (isWithinInterval(inD, interval)) {
      records.push({
        employeeId,
        companyId,
        clockIn: r.clockIn,
        clockOut: r.clockOut ?? null,
        notes: r.notes ?? null,
      });
    }
  });

  records.sort((a, b) => a.clockIn.localeCompare(b.clockIn));
  return records;
}

function buildPdf({ companyName, employeeName, monthLabel, records }) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 36 });
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    doc.fontSize(16).text('Reporte mensual de fichajes', { align: 'center' });
    doc.moveDown(0.5);
    doc.fontSize(11).text(`Empresa: ${companyName}`);
    doc.text(`Empleado: ${employeeName}`);
    doc.text(`Periodo: ${monthLabel}`);
    doc.moveDown();

    doc.fontSize(11).text(
        'Fecha         Entrada   Salida    Horas     Notas',
    );
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

async function uploadPdf({ companyId, employeeId, monthKey, buffer }) {
  const path = `reports/${companyId}/${monthKey}/${employeeId}.pdf`;
  const file = storage.bucket().file(path);
  await file.save(buffer, {
    contentType: 'application/pdf',
    resumable: false,
    metadata: { cacheControl: 'public, max-age=3600' },
  });
  const [url] = await file.getSignedUrl({
    action: 'read',
    expires: Date.now() + 1000 * 60 * 60 * 24 * 30,
  });
  return { path, url };
}

async function writeReportDocs({
  companyId,
  monthKey,
  periodStart,
  periodEnd,
  employeeId,
  pdfPath,
  downloadUrl,
  totalHours,
  daysCount,
}) {
  const base = db
      .collection('companies')
      .doc(companyId)
      .collection('monthlyReports')
      .doc(monthKey);

  await base.set(
      {
        periodStart: periodStart.toISOString(),
        periodEnd: periodEnd.toISOString(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
  );

  await base.collection('employees').doc(employeeId).set(
      {
        pdfPath,
        downloadUrl,
        totalHours,
        daysCount,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
  );
}

async function sendEmail({ company, monthKey, pdfs }) {
  const recipients = await getCompanyEmails(company);
  if (!recipients.length) return;

  const apiKey = process.env.SENDGRID_API_KEY;
  if (!apiKey) {
    // eslint-disable-next-line no-console
    console.warn('SENDGRID_API_KEY no configurada; omitiendo envío.');
    return;
  }
  sg.setApiKey(apiKey);

  await sg.send({
    to: recipients,
    from: { email: 'no-reply@yourdomain.com', name: 'FarmaTime' },
    subject: `Reportes de fichajes ${monthKey}`,
    text:
      'Adjuntamos los reportes PDF. ' +
      'También están disponibles en la app.',
    attachments: pdfs.map((p) => ({
      content: p.buffer.toString('base64'),
      filename: p.filename,
      type: 'application/pdf',
      disposition: 'attachment',
    })),
  });
}

/**
 * Genera PDFs para una empresa en un intervalo.
 * @param {string} companyId
 * @param {Date} targetDate  Fecha dentro del mes objetivo
 * @param {boolean} toDate   true => hasta HOY; false => mes completo
 */
async function generateForCompany(companyId, targetDate, toDate) {
  const company = await getCompany(companyId);
  const periodStart = startOfMonth(targetDate);
  const monthKey = yyyyMM(periodStart);
  const monthEnd = endOfMonth(targetDate);
  const periodEnd = toDate ? new Date() : monthEnd;

  const employees = await getEmployees(companyId);
  const emailBuffers = [];

  for (const emp of employees) {
    const records = await getClockRecords(
        companyId,
        emp.id,
        periodStart,
        periodEnd,
    );
    if (!records.length) continue;

    const totalHours = records.reduce(
        (acc, r) => acc + diffHours(r.clockIn, r.clockOut),
        0,
    );
    const daysCount = records.filter((r) => r.clockOut).length;

    const pdfBuffer = await buildPdf({
      companyName: company.name || companyId,
      employeeName: emp.name || emp.id,
      monthLabel: toDate ?
        `${monthKey} (hasta ${format(periodEnd, 'yyyy-MM-dd')})` :
        monthKey,
      records,
    });

    const { path, url } = await uploadPdf({
      companyId,
      employeeId: emp.id,
      monthKey,
      buffer: pdfBuffer,
    });

    await writeReportDocs({
      companyId,
      monthKey,
      periodStart,
      periodEnd,
      employeeId: emp.id,
      pdfPath: path,
      downloadUrl: url,
      totalHours,
      daysCount,
    });

    emailBuffers.push({
      filename: `${emp.name || emp.id}-${monthKey}.pdf`,
      buffer: pdfBuffer,
    });
  }

  if (emailBuffers.length) {
    await sendEmail({ company, monthKey, pdfs: emailBuffers });
  }

  return {
    companyId,
    monthKey,
    generated: emailBuffers.length,
    periodStart: periodStart.toISOString(),
    periodEnd: periodEnd.toISOString(),
  };
}

// ============ EXPORTS ============

// HTTP manual: “lo que va de mes” (hasta hoy).
// GET/POST ?companyId=XYZ[&date=YYYY-MM-DD]
const reportsGenerateMonthToDate = onRequest(async (req, res) => {
  try {
    const companyId = req.query.companyId || (req.body && req.body.companyId);
    if (!companyId) {
      return res.status(400).json({ error: 'companyId requerido' });
    }

    const dateStr = req.query.date || (req.body && req.body.date);
    const baseDate = dateStr ? new Date(dateStr) : new Date();

    const result = await generateForCompany(companyId, baseDate, true);
    return res.json(result);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: String(err && err.message) });
  }
});

// Programada: día 1 a las 01:00, genera el mes anterior completo.
const reportsScheduleMonthly = onSchedule(
    { schedule: '0 1 1 * *', timeZone: 'Europe/Madrid' },
    async () => {
      const companies = await db
          .collection('companies')
          .where('isActive', '==', true)
          .get();
      const ref = new Date();
      ref.setMonth(ref.getMonth() - 1);
      for (const c of companies.docs) {
        // eslint-disable-next-line no-await-in-loop
        await generateForCompany(c.id, ref, false);
      }
    },
);

module.exports = {
  reportsGenerateMonthToDate,
  reportsScheduleMonthly,
};
