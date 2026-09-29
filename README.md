# BrightBrush Creations

Ordering, production and delivery app for a Kenyan embroidery and branding business. Flutter (web, Android, iOS) on Firebase: Auth, Firestore (named database `brightbrush-main`), Storage, Cloud Functions, Hosting.

## Layout

| Path | What |
| --- | --- |
| `lib/` | Flutter app. Role shells: customer, delivery staff, system manager, admin, developer |
| `functions/` | Cloud Functions (TypeScript): server-side order pricing, quotes, payments, account deletion |
| `firestore.rules`, `storage.rules` | Security rules |
| `rules_tests/` | Security-rules tests, run against the Firestore emulator |
| `seed/` | One-off data seeding scripts |

## Money never comes from the client

- **Orders are created only by Cloud Functions.** `placeOrder` prices the customer's saved cart from `CatalogItems`/`Packages`, enforces MOQ, applies VAT, delivery and deposit rules from `Settings/business`, and assigns an order number (`BB-000123`). `acceptQuote` does the same for a staff-priced quote. `firestore.rules` denies every client `create` on `Orders`.
- **Payments go through one ledger.** `Payments/{id}` records every attempt. Only `functions/src/payments/ledger.ts` credits `amountPaid` and sets `paymentStatus` (`unpaid` → `partiallyPaid` → `paid`), idempotently, so a retried webhook is never counted twice. Staff record cash or bank payments through the same ledger (`recordManualPayment`).

## Branding and embroidery

- **Customisable items.** In the catalog form, managers turn on "Customisable" and choose decoration methods, placements, sizes (with surcharges), colours and volume price tiers.
- **Configurator.** Customers pick a colour and quantities per size, then add decorations: placement, method, design size, a logo from their artwork library or text, and thread colours. They see the result on a live mockup and can add per-piece names. The configured line is saved in `Carts/{uid}.lines`, and `placeOrder` prices it on the server (`functions/src/customization/pricing.ts`).
- **Branding rates** (Payments & Settings → Branding rates, stored in `Settings/decoration`) set, per method, a one-off setup fee, a per-piece price by design size (small, medium, large) and, for embroidery, a rate per 1000 stitches.
- **Artwork library.** Customers upload a logo once (`Artworks`, Storage path `artwork/{uid}/…`). In **Manager → Artwork**, staff attach DST/EMB/PES files and the stitch count and mark the logo digitized. Embroidering a digitized logo carries no digitizing fee and is priced by stitches.
- **Proof approval.** Staff send a proof from the order (`sendProof`) and the customer approves it or asks for changes (`respondToProof`). The rules keep a decorated order out of production until its proof is approved.
- **Order again** puts a past order's lines back in the cart, with the same artwork and placements. Prices are recalculated at checkout.

## Payment gateways

M-Pesa (Daraja STK Push), Stripe Checkout, PayPal and Flutterwave are fully implemented. Each stays hidden from customers until an **Admin** opens **Payments & Settings**, pastes that provider's credentials, passes **Test connection**, and switches it on.

- Credentials live in `PaymentGatewaySecrets/{id}`. No client can read that collection, admins included. Only the Admin SDK can.
- The admin screen shows the webhook URLs to register:
  - Stripe: `…/stripeWebhook` (events `checkout.session.*`)
  - Flutterwave: `…/flutterwaveWebhook`, plus the same secret hash in both places
  - M-Pesa and PayPal callback URLs are set automatically on each payment.
- Start in **Sandbox**, then switch to **Live** once a test payment completes.
- PayPal can't charge KES. Set the charge currency and the KES exchange rate on the PayPal card.

## Deploying

The Cloud Functions need the **Blaze** (pay-as-you-go) plan, and the functions call external APIs.

The new rules block the old client-side order creation. Deploy in this order so the live app never breaks:

```bash
cd functions && npm install && npm test && cd ..
npx firebase-tools deploy --only functions         # 1. backend first
flutter build web --release
npx firebase-tools deploy --only hosting           # 2. app that calls the backend
npx firebase-tools deploy --only firestore         # 3. then lock the rules and indexes
```

Mobile builds released before this change still try to write `Orders` directly, and will fail once the rules are deployed. Ship the updated mobile build too.

## Tests

```bash
flutter test                         # app (includes checkout pricing parity with the server)
cd functions && npm test             # pricing, M-Pesa, Stripe, Flutterwave, PayPal helpers
cd rules_tests && npm install && npm test   # security rules on the emulator (needs Java)
```
