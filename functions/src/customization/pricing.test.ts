import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  DEFAULT_DECORATION_PRICING as P,
  ItemOptions,
  LineConfig,
  ONE_SIZE,
  parseDecorationPricing,
  parseItemOptions,
  priceLine,
  tierPrice,
  validateLine,
} from './pricing';

const polo: ItemOptions = {
  basePrice: 800,
  moq: 10,
  priceTiers: [
    { minQty: 50, unitPrice: 700 },
    { minQty: 100, unitPrice: 650 },
  ],
  sizes: [
    { label: 'M', surcharge: 0 },
    { label: 'L', surcharge: 0 },
    { label: 'XXL', surcharge: 100 },
  ],
  colours: ['Navy', 'White'],
  decorationMethods: ['embroidery', 'dtf'],
  placements: ['leftChest', 'fullBack', 'leftSleeve', 'rightSleeve'],
};

const logo = (extra: Partial<LineConfig['decorations'][number]> = {}) => ({
  method: 'embroidery' as const,
  placement: 'leftChest' as const,
  sizeClass: 'small' as const,
  artworkId: 'art1',
  threadColours: ['White'],
  ...extra,
});

describe('tierPrice', () => {
  it('uses the highest tier reached', () => {
    assert.equal(tierPrice(polo, 10), 800);
    assert.equal(tierPrice(polo, 50), 700);
    assert.equal(tierPrice(polo, 99), 700);
    assert.equal(tierPrice(polo, 250), 650);
  });
});

describe('priceLine', () => {
  it('prices blanks with size surcharges, decoration per piece and a one-off setup', () => {
    const p = priceLine(
      polo,
      { colour: 'Navy', sizeQuantities: { M: 20, XXL: 5 }, decorations: [logo()], names: [] },
      P,
    );
    assert.equal(p.quantity, 25);
    assert.equal(p.blankTotal, 20 * 800 + 5 * 900);
    assert.equal(p.decorationPerUnit, 150);
    assert.equal(p.setupFees, 1500);
    assert.equal(p.lineTotal, 20500 + 25 * 150 + 1500);
  });

  it('waives embroidery digitizing and prices by stitch count once digitized', () => {
    const p = priceLine(
      polo,
      {
        colour: 'Navy',
        sizeQuantities: { M: 10 },
        decorations: [logo({ digitized: true, stitchCount: 8200 })],
        names: [],
      },
      P,
    );
    assert.equal(p.setupFees, 0);
    assert.equal(p.decorationPerUnit, 9 * 40);
  });

  it('charges setup once for the same design on two placements', () => {
    const p = priceLine(
      polo,
      {
        colour: 'White',
        sizeQuantities: { L: 10 },
        decorations: [logo({ placement: 'leftSleeve' }), logo({ placement: 'rightSleeve' })],
        names: [],
      },
      P,
    );
    assert.equal(p.setupFees, 1500);
    assert.equal(p.decorationPerUnit, 300);
  });

  it('adds personalisation per named piece', () => {
    const p = priceLine(
      polo,
      { colour: 'Navy', sizeQuantities: { M: 10 }, decorations: [], names: ['Ann', 'Joe', ' '] },
      P,
    );
    assert.equal(p.personalisationTotal, 2 * 200);
  });
});

describe('validateLine', () => {
  const ok: LineConfig = { colour: 'Navy', sizeQuantities: { M: 10 }, decorations: [logo()], names: [] };
  it('accepts a valid line', () => assert.equal(validateLine(polo, ok, P), null));
  it('enforces MOQ across all sizes', () =>
    assert.match(validateLine(polo, { ...ok, sizeQuantities: { M: 5, L: 4 } }, P) ?? '', /minimum/));
  it('rejects unknown sizes, colours, methods and placements', () => {
    assert.ok(validateLine(polo, { ...ok, sizeQuantities: { S: 10 } }, P));
    assert.ok(validateLine(polo, { ...ok, colour: 'Pink' }, P));
    assert.ok(validateLine(polo, { ...ok, decorations: [logo({ method: 'screenPrint' })] }, P));
    assert.ok(validateLine(polo, { ...ok, decorations: [logo({ placement: 'capFront' })] }, P));
  });
  it('rejects a decoration with neither artwork nor text', () =>
    assert.ok(validateLine(polo, { ...ok, decorations: [logo({ artworkId: undefined })] }, P)));
  it('rejects disabled methods', () => {
    const off = parseDecorationPricing({ methods: { embroidery: { enabled: false } } });
    assert.ok(validateLine(polo, ok, off));
  });
  it('items without sizes use the one-size key', () => {
    const cap = { ...polo, sizes: [], colours: [] };
    assert.equal(validateLine(cap, { sizeQuantities: { [ONE_SIZE]: 10 }, decorations: [logo()], names: [] }, P), null);
  });
});

describe('parsers', () => {
  it('fall back to defaults for bad values', () => {
    const p = parseDecorationPricing({ personalisationFee: -5, methods: { dtf: { setupFee: 'x' } } });
    assert.equal(p.personalisationFee, 200);
    assert.equal(p.methods.dtf.setupFee, 0);
  });
  it('read colour objects and drop unknown methods/placements', () => {
    const o = parseItemOptions({
      basePrice: 500,
      colours: [{ name: 'Red', hex: '#f00' }],
      decorationMethods: ['embroidery', 'glitter'],
      placements: ['capFront', 'moon'],
    });
    assert.deepEqual(o.colours, ['Red']);
    assert.deepEqual(o.decorationMethods, ['embroidery']);
    assert.deepEqual(o.placements, ['capFront']);
    assert.equal(o.moq, 1);
  });
});
