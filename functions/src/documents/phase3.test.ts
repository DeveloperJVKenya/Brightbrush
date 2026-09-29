import assert from 'node:assert/strict';
import { writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';

import { buildSalePayload, etimsDateTime, etimsQrUrl, paymentTypeFor } from '../etims/etims_payload';
import { allocateRefund } from '../payments/refunds';
import { DEFAULT_BUSINESS_SETTINGS } from '../settings/business_settings';
import { renderPdf } from './pdf';

describe('PDF rendering', () => {
  it('renders a multi-line invoice with an eTIMS QR block', async () => {
    const pdf = await renderPdf(
      { ...DEFAULT_BUSINESS_SETTINGS, kraPin: 'P051234567X', physicalAddress: 'Moi Ave, Nairobi' },
      {
        title: 'Tax invoice',
        number: 'INV-000042',
        date: new Date('2026-09-29T08:00:00Z'),
        meta: [['Order', 'BB-000042']],
        billTo: ['Acme Ltd', 'Jane W.', '0712345678'],
        lines: Array.from({ length: 40 }, (_, i) => ({
          description: `Embroidered polo ${i + 1}`,
          detail: 'Navy · M×10 · leftChest embroidery small Logo',
          quantity: 10,
          unitPrice: 950,
          amount: 9500,
        })),
        totals: [
          { label: 'Subtotal', amount: 380000 },
          { label: 'Total', amount: 380000, bold: true },
        ],
        etims: { qrUrl: 'https://etims-sbx.kra.go.ke/x', lines: ['CU invoice no: KRA/1'] },
        notes: ['How to pay: Paybill 123456'],
      },
    );
    assert.equal(pdf.subarray(0, 4).toString(), '%PDF');
    assert.ok(pdf.length > 3000);
    writeFileSync(join(tmpdir(), 'brightbrush-invoice-test.pdf'), pdf);
  });
});

describe('eTIMS payload', () => {
  const base = {
    tin: 'P051234567X',
    bhfId: '00',
    invcNo: 7,
    trdInvcNo: 'INV-000007',
    kind: 'sale' as const,
    customerName: 'Acme',
    salesDate: new Date('2026-09-29T21:30:00Z'),
    confirmDate: new Date('2026-09-29T21:30:00Z'),
    paymentTypeCode: '06',
    vatRegistered: true,
    itemCode: 'KE1NTXU0000001',
    itemClassCode: '5310150000',
    lines: [
      { name: 'Polo', quantity: 10, lineTotal: 11600 },
      { name: 'Delivery', quantity: 1, lineTotal: 580 },
    ],
    discount: 0,
    businessName: 'BrightBrush',
    address: '',
  };

  it('extracts 16% VAT from inclusive amounts under tax type B', () => {
    const p = buildSalePayload(base) as any;
    assert.equal(p.taxblAmtB, 12180);
    assert.equal(p.taxAmtB, 1600 + 80);
    assert.equal(p.totAmt, 12180);
    assert.equal(p.itemList[0].taxTyCd, 'B');
    assert.equal(p.rcptTyCd, 'S');
    assert.equal(p.salesDt, '20260930');
  });

  it('uses tax type D with no VAT when not VAT registered', () => {
    const p = buildSalePayload({ ...base, vatRegistered: false }) as any;
    assert.equal(p.taxblAmtD, 12180);
    assert.equal(p.totTaxAmt, 0);
  });

  it('spreads an invoice discount across lines and marks credit notes', () => {
    const p = buildSalePayload({ ...base, discount: 1218, kind: 'creditNote', orgInvcNo: 3 }) as any;
    assert.equal(p.itemList[0].dcRt, 10);
    assert.equal(p.totAmt, 10962);
    assert.equal(p.rcptTyCd, 'R');
    assert.equal(p.orgInvcNo, 3);
  });

  it('formats dates in EAT and builds the verification link', () => {
    assert.equal(etimsDateTime(new Date('2026-01-31T22:05:09Z')), '20260201010509');
    assert.match(etimsQrUrl(false, 'P0', '00', 'SIG'), /^https:\/\/etims-sbx\.kra\.go\.ke\/.*Data=P000SIG$/);
    assert.equal(paymentTypeFor('mpesa', false), '06');
    assert.equal(paymentTypeFor('stripe', true), '02');
  });
});

describe('allocateRefund', () => {
  const sources = [
    { id: 'old', available: 5000, createdAt: 1 },
    { id: 'new', available: 3000, createdAt: 2 },
  ];
  it('takes from the newest payment first', () => {
    assert.deepEqual(allocateRefund(sources, 4000), [
      { id: 'new', amount: 3000 },
      { id: 'old', amount: 1000 },
    ]);
  });
  it('refuses more than was paid', () => {
    assert.throws(() => allocateRefund(sources, 9000));
  });
});
