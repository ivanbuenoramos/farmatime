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

  console.log('[reports] clockRecords encontrados', {
    companyId,
    employeeId,
    count: snap.size,
    start: start.toISOString(),
    end: end.toISOString(),
  });

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

  console.log('[reports] clockRecords finales tras mapeo:', records.length);

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
        daysCount += 1;
      }
    }

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

      // Agrupamos ediciones por día (fecha del clockIn)
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

  const periodLabel = `${format(periodStart, 'dd/MM/yyyy')} - ${format(
      periodEnd,
      'dd/MM/yyyy',
  )}`;

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
      company,
      employee: emp,
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
