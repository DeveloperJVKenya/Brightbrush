/// Builds KRA eTIMS OSCU `saveTrnsSalesOsdc` payloads from an order. Pure
/// (no Firebase), so the tax maths is unit-tested. eTIMS amounts are
/// VAT-inclusive; tax is extracted per line (2dp, half-up) and summed.

export interface EtimsLineInput {
  name: string;
  quantity: number;
  /// VAT-inclusive total for the line, before any invoice discount.
  lineTotal: number;
}

export interface EtimsSaleInput {
  tin: string;
  bhfId: string;
  invcNo: number;
  /// For credit notes: the original eTIMS invoice number.
  orgInvcNo?: number;
  trdInvcNo: string;
  kind: 'sale' | 'creditNote';
  customerName: string;
  customerTin?: string;
  /// When the sale was confirmed (order date) and when this is submitted.
  salesDate: Date;
  confirmDate: Date;
  /// '02' credit, '06' mobile money, '05' card, '01' cash...
  paymentTypeCode: string;
  vatRegistered: boolean;
  itemCode: string;
  itemClassCode: string;
  lines: EtimsLineInput[];
  /// Invoice-level discount (VAT-inclusive) spread across lines.
  discount: number;
  businessName: string;
  address: string;
}

const round2 = (v: number) => Math.round((v + Number.EPSILON) * 100) / 100;

/// yyyyMMddHHmmss in East Africa Time.
export function etimsDateTime(date: Date): string {
  const eat = new Date(date.getTime() + 3 * 3600 * 1000);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${eat.getUTCFullYear()}${p(eat.getUTCMonth() + 1)}${p(eat.getUTCDate())}${p(eat.getUTCHours())}${p(eat.getUTCMinutes())}${p(eat.getUTCSeconds())}`;
}

export function etimsDate(date: Date): string {
  return etimsDateTime(date).slice(0, 8);
}

export function buildSalePayload(input: EtimsSaleInput): Record<string, unknown> {
  // B = standard 16% VAT; D = non-VAT (seller not VAT registered).
  const taxType = input.vatRegistered ? 'B' : 'D';
  const rate = input.vatRegistered ? 16 : 0;
  const gross = input.lines.reduce((s, l) => s + l.lineTotal, 0);
  const dcRt = gross > 0 ? round2((Math.min(input.discount, gross) / gross) * 100) : 0;

  let totTaxbl = 0;
  let totTax = 0;
  const itemList = input.lines.map((line, i) => {
    const qty = Math.max(1, line.quantity);
    const splyAmt = round2(line.lineTotal);
    const dcAmt = round2((splyAmt * dcRt) / 100);
    const taxblAmt = round2(splyAmt - dcAmt);
    const taxAmt = rate > 0 ? round2((taxblAmt * rate) / (100 + rate)) : 0;
    totTaxbl += taxblAmt;
    totTax += taxAmt;
    return {
      itemSeq: i + 1,
      itemCd: input.itemCode,
      itemClsCd: input.itemClassCode,
      itemNm: line.name.slice(0, 200),
      bcd: null,
      pkgUnitCd: 'NT',
      pkg: qty,
      qtyUnitCd: 'U',
      qty,
      prc: round2(splyAmt / qty),
      splyAmt,
      dcRt,
      dcAmt,
      isrccCd: null,
      isrccNm: null,
      isrcRt: null,
      isrcAmt: null,
      taxTyCd: taxType,
      taxblAmt,
      taxAmt,
      totAmt: taxblAmt,
    };
  });
  totTaxbl = round2(totTaxbl);
  totTax = round2(totTax);
  const amounts = (code: string) => (code === taxType ? totTaxbl : 0);
  const taxes = (code: string) => (code === taxType ? totTax : 0);

  return {
    tin: input.tin,
    bhfId: input.bhfId,
    trdInvcNo: input.trdInvcNo,
    invcNo: input.invcNo,
    orgInvcNo: input.orgInvcNo ?? 0,
    custTin: input.customerTin || null,
    custNm: input.customerName.slice(0, 60),
    salesTyCd: 'N',
    rcptTyCd: input.kind === 'creditNote' ? 'R' : 'S',
    pmtTyCd: input.paymentTypeCode,
    salesSttsCd: '02',
    cfmDt: etimsDateTime(input.confirmDate),
    salesDt: etimsDate(input.salesDate),
    stockRlsDt: null,
    cnclReqDt: null,
    cnclDt: null,
    rfdDt: input.kind === 'creditNote' ? etimsDateTime(input.confirmDate) : null,
    rfdRsnCd: input.kind === 'creditNote' ? '06' : null,
    totItemCnt: itemList.length,
    taxblAmtA: amounts('A'),
    taxblAmtB: amounts('B'),
    taxblAmtC: amounts('C'),
    taxblAmtD: amounts('D'),
    taxblAmtE: amounts('E'),
    taxRtA: 0,
    taxRtB: 16,
    taxRtC: 0,
    taxRtD: 0,
    taxRtE: 8,
    taxAmtA: taxes('A'),
    taxAmtB: taxes('B'),
    taxAmtC: taxes('C'),
    taxAmtD: taxes('D'),
    taxAmtE: taxes('E'),
    totTaxblAmt: totTaxbl,
    totTaxAmt: totTax,
    totAmt: totTaxbl,
    prchrAcptcYn: 'N',
    remark: null,
    regrId: 'brightbrush',
    regrNm: 'BrightBrush',
    modrId: 'brightbrush',
    modrNm: 'BrightBrush',
    receipt: {
      custTin: input.customerTin || null,
      custMblNo: null,
      rptNo: null,
      trdeNm: input.businessName.slice(0, 60),
      adrs: input.address.slice(0, 200) || null,
      topMsg: input.businessName.slice(0, 60),
      btmMsg: 'Thank you',
      prchrAcptcYn: 'N',
    },
    itemList,
  };
}

/// Public receipt-verification link encoded in the invoice QR code.
export function etimsQrUrl(live: boolean, tin: string, bhfId: string, rcptSign: string): string {
  const host = live ? 'etims.kra.go.ke' : 'etims-sbx.kra.go.ke';
  return `https://${host}/common/link/etims/receipt/indexEtimsReceiptData?Data=${encodeURIComponent(`${tin}${bhfId}${rcptSign}`)}`;
}

/// Maps the gateway used to an eTIMS payment type code.
export function paymentTypeFor(gateway: string | undefined, credit: boolean): string {
  if (credit) return '02';
  switch (gateway) {
    case 'mpesa':
    case 'mpesaManual':
      return '06';
    case 'stripe':
    case 'flutterwave':
    case 'paypal':
      return '05';
    case 'bankTransfer':
    case 'cheque':
      return '04';
    case 'cash':
      return '01';
    default:
      return '07';
  }
}
