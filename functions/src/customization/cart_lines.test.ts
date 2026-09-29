import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { HttpsError } from 'firebase-functions/v2/https';

import { parseCartLines } from './cart_lines';

describe('parseCartLines', () => {
  it('parses a well-formed line and clamps untrusted values', () => {
    const [line] = parseCartLines({
      l1: {
        itemId: 'polo',
        colour: 'Navy',
        sizeQuantities: { M: 12.7, L: -3, XL: 'x' },
        decorations: [
          {
            method: 'embroidery',
            placement: 'leftChest',
            sizeClass: 'huge',
            artworkId: 'a1',
            threadColours: ['White', 5, ''],
            offsetX: 4,
            stitchCount: 999999,
            digitized: true,
          },
        ],
        names: ['Ann', '', 7],
      },
    });
    assert.equal(line.itemId, 'polo');
    assert.deepEqual(line.config.sizeQuantities, { M: 12 });
    const d = line.config.decorations[0];
    assert.equal(d.sizeClass, 'small');
    assert.deepEqual(d.threadColours, ['White']);
    assert.equal(d.offsetX, 1);
    // Pricing facts are never taken from the client.
    assert.equal(d.stitchCount, undefined);
    assert.equal(d.digitized, undefined);
    assert.deepEqual(line.config.names, ['Ann']);
  });

  it('rejects unknown methods/placements with a friendly error', () => {
    assert.throws(
      () => parseCartLines({ l1: { itemId: 'x', decorations: [{ method: 'glitter', placement: 'leftChest' }] } }),
      (e: unknown) => e instanceof HttpsError && e.code === 'failed-precondition',
    );
    assert.throws(() => parseCartLines({ l1: { decorations: [] } }), HttpsError);
  });

  it('treats a missing or malformed lines map as empty', () => {
    assert.deepEqual(parseCartLines(undefined), []);
    assert.deepEqual(parseCartLines('nope'), []);
  });
});
