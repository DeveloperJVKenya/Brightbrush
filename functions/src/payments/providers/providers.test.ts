import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { describe, it } from 'node:test';

import { verifyFlutterwaveHash } from './flutterwave';
import { darajaTimestamp, mapResultCode, normalizeKenyanPhone } from './mpesa';
import { convertFromKes } from './paypal';
import { verifyStripeSignature } from './stripe';

describe('M-Pesa helpers', () => {
  it('normalises Kenyan numbers', () => {
    assert.equal(normalizeKenyanPhone('0712 345 678'), '254712345678');
    assert.equal(normalizeKenyanPhone('+254-110-345-678'), '254110345678');
    assert.equal(normalizeKenyanPhone('712345678'), '254712345678');
    assert.equal(normalizeKenyanPhone('254712345678'), '254712345678');
    assert.equal(normalizeKenyanPhone('0812345678'), null);
    assert.equal(normalizeKenyanPhone('12345'), null);
  });

  it('formats Daraja timestamps in EAT', () => {
    assert.equal(darajaTimestamp(new Date('2026-01-31T22:05:09Z')), '20260201010509');
  });

  it('maps STK result codes', () => {
    assert.equal(mapResultCode('0').state, 'succeeded');
    assert.equal(mapResultCode('1032').state, 'cancelled');
    assert.equal(mapResultCode('1037').state, 'failed');
  });
});

describe('Stripe signature', () => {
  const secret = 'whsec_test';
  const body = Buffer.from('{"id":"evt_1"}');
  const sign = (t: number) =>
    `t=${t},v1=${createHmac('sha256', secret).update(`${t}.${body}`).digest('hex')}`;

  it('accepts a fresh valid signature', () => {
    assert.equal(verifyStripeSignature(body, sign(Math.floor(Date.now() / 1000)), secret), true);
  });
  it('rejects tampered bodies, wrong secrets and stale timestamps', () => {
    const now = Math.floor(Date.now() / 1000);
    assert.equal(verifyStripeSignature(Buffer.from('{}'), sign(now), secret), false);
    assert.equal(verifyStripeSignature(body, sign(now), 'other'), false);
    assert.equal(verifyStripeSignature(body, sign(now - 3600), secret), false);
    assert.equal(verifyStripeSignature(body, undefined, secret), false);
  });
});

describe('Flutterwave + PayPal helpers', () => {
  it('compares the webhook hash exactly', () => {
    assert.equal(verifyFlutterwaveHash('abc123', 'abc123'), true);
    assert.equal(verifyFlutterwaveHash('abc124', 'abc123'), false);
    assert.equal(verifyFlutterwaveHash(undefined, 'abc123'), false);
  });
  it('converts KES to the PayPal currency at 2dp', () => {
    assert.equal(convertFromKes(12950, 129.5), 100);
    assert.equal(convertFromKes(1000, 129.5), 7.72);
  });
});
