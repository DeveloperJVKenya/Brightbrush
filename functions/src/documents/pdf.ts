import PDFDocument from 'pdfkit';
import QRCode from 'qrcode';

import { BusinessSettings } from '../settings/business_settings';

export interface DocLine {
  description: string;
  detail?: string;
  quantity: number;
  unitPrice: number;
  amount: number;
}

export interface DocTotalRow {
  label: string;
  amount: number;
  bold?: boolean;
}

export interface DocSpec {
  title: string;
  number: string;
  date: Date;
  meta: Array<[string, string]>;
  billTo: string[];
  lines: DocLine[];
  totals: DocTotalRow[];
  notes: string[];
  /// eTIMS block: printed with a QR code of the KRA verification link.
  etims?: { lines: string[]; qrUrl?: string | null };
  /// Plain table (statements) instead of item lines.
  table?: { headers: string[]; widths: number[]; rows: string[][]; alignRight: number[] };
}

const money = (v: number) =>
  `KES ${Math.round(v).toLocaleString('en-KE', { maximumFractionDigits: 0 })}`;

export const formatMoney = money;

export function formatDate(d: Date): string {
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', timeZone: 'Africa/Nairobi' });
}

/// Renders a branded A4 document to a PDF buffer.
export async function renderPdf(settings: BusinessSettings, spec: DocSpec): Promise<Buffer> {
  const doc = new PDFDocument({ size: 'A4', margin: 48, info: { Title: `${spec.title} ${spec.number}`, Author: settings.businessName } });
  const chunks: Buffer[] = [];
  doc.on('data', (c: Buffer) => chunks.push(c));
  const done = new Promise<Buffer>((resolve) => doc.on('end', () => resolve(Buffer.concat(chunks))));

  const left = 48;
  const right = doc.page.width - 48;
  const width = right - left;
  const accent = '#5B2A86';

  // Header: business block left, document title right.
  doc.fillColor(accent).font('Helvetica-Bold').fontSize(18).text(settings.businessName, left, 48, { width: width * 0.6 });
  doc.fillColor('#333').font('Helvetica').fontSize(9);
  const biz = [
    settings.physicalAddress,
    [settings.supportPhone, settings.supportEmail].filter(Boolean).join(' · '),
    settings.kraPin ? `KRA PIN: ${settings.kraPin}` : '',
  ].filter(Boolean);
  for (const line of biz) doc.text(line, { width: width * 0.6 });

  doc.font('Helvetica-Bold').fontSize(20).fillColor('#111')
    .text(spec.title.toUpperCase(), left + width * 0.55, 48, { width: width * 0.45, align: 'right' });
  doc.font('Helvetica').fontSize(10).fillColor('#333')
    .text(spec.number, { width: width * 0.45, align: 'right' })
    .text(formatDate(spec.date), { width: width * 0.45, align: 'right' });
  for (const [k, v] of spec.meta) doc.text(`${k}: ${v}`, { width: width * 0.45, align: 'right' });

  let y = Math.max(doc.y, 150) + 12;
  doc.moveTo(left, y).lineTo(right, y).strokeColor('#DDD').stroke();
  y += 10;
  doc.font('Helvetica-Bold').fontSize(9).fillColor('#777').text('BILL TO', left, y);
  doc.font('Helvetica').fontSize(10).fillColor('#111');
  for (const line of spec.billTo.filter(Boolean)) doc.text(line, left, doc.y, { width: width * 0.6 });
  y = doc.y + 16;

  if (spec.table) {
    y = drawTable(doc, left, y, spec.table.headers, spec.table.widths, spec.table.rows, spec.table.alignRight);
  } else {
    const cols = [width * 0.52, width * 0.1, width * 0.18, width * 0.2];
    y = drawTable(
      doc,
      left,
      y,
      ['Description', 'Qty', 'Unit price', 'Amount'],
      cols,
      spec.lines.map((l) => [
        l.detail ? `${l.description}\n${l.detail}` : l.description,
        String(l.quantity),
        money(l.unitPrice),
        money(l.amount),
      ]),
      [1, 2, 3],
    );
  }

  // Totals block, right aligned.
  y += 8;
  for (const t of spec.totals) {
    if (y > doc.page.height - 120) {
      doc.addPage();
      y = 48;
    }
    doc.font(t.bold ? 'Helvetica-Bold' : 'Helvetica').fontSize(t.bold ? 11 : 10).fillColor('#111');
    doc.text(t.label, left + width * 0.45, y, { width: width * 0.3, align: 'right' });
    doc.text(money(t.amount), left + width * 0.75, y, { width: width * 0.25, align: 'right' });
    y += t.bold ? 18 : 15;
  }

  if (spec.etims) {
    y += 10;
    if (y > doc.page.height - 150) {
      doc.addPage();
      y = 48;
    }
    const qrSize = 90;
    if (spec.etims.qrUrl) {
      const png = await QRCode.toBuffer(spec.etims.qrUrl, { margin: 1, width: qrSize * 2 });
      doc.image(png, left, y, { width: qrSize });
    }
    doc.font('Helvetica-Bold').fontSize(9).fillColor('#111').text('KRA eTIMS', left + qrSize + 12, y);
    doc.font('Helvetica').fontSize(8).fillColor('#333');
    for (const line of spec.etims.lines) doc.text(line, left + qrSize + 12, doc.y, { width: width - qrSize - 12 });
    y = Math.max(doc.y, y + qrSize) + 10;
  }

  if (spec.notes.length) {
    doc.font('Helvetica').fontSize(9).fillColor('#444');
    doc.text('', left, y + 6);
    for (const n of spec.notes.filter(Boolean)) doc.text(n, left, doc.y + 4, { width });
  }

  doc.fontSize(8).fillColor('#999').text(
    settings.invoiceFooter,
    left,
    doc.page.height - 60,
    { width, align: 'center', lineBreak: false },
  );
  doc.end();
  return done;
}

function drawTable(
  doc: PDFKit.PDFDocument,
  left: number,
  startY: number,
  headers: string[],
  widths: number[],
  rows: string[][],
  alignRight: number[],
): number {
  let y = startY;
  const drawHeader = () => {
    doc.rect(left, y, widths.reduce((a, b) => a + b, 0), 20).fill('#F2EEF7');
    doc.font('Helvetica-Bold').fontSize(9).fillColor('#333');
    let x = left;
    headers.forEach((h, i) => {
      doc.text(h, x + 4, y + 6, { width: widths[i] - 8, align: alignRight.includes(i) ? 'right' : 'left' });
      x += widths[i];
    });
    y += 24;
  };
  drawHeader();
  doc.font('Helvetica').fontSize(9).fillColor('#111');
  for (const row of rows) {
    const heights = row.map((cell, i) => doc.heightOfString(cell, { width: widths[i] - 8 }));
    const h = Math.max(...heights, 12) + 6;
    if (y + h > doc.page.height - 110) {
      doc.addPage();
      y = 48;
      drawHeader();
      doc.font('Helvetica').fontSize(9).fillColor('#111');
    }
    let x = left;
    row.forEach((cell, i) => {
      doc.text(cell, x + 4, y, { width: widths[i] - 8, align: alignRight.includes(i) ? 'right' : 'left' });
      x += widths[i];
    });
    y += h;
    doc.moveTo(left, y - 3).lineTo(left + widths.reduce((a, b) => a + b, 0), y - 3).strokeColor('#EEE').stroke();
  }
  return y;
}
