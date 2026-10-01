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

## Money, tax and documents

- **PDFs** (`getDocument`): the tax invoice (`INV-` number, same sequence as orders), a receipt per payment (`RCT-`), credit notes (`CN-`), quotes and account statements. They are generated on the server with pdfkit and downloaded or shared from the order page, Profile, or the staff screens.
- **KRA eTIMS** (Payments & Settings → KRA eTIMS): enter the OSCU details from your eTIMS registration, then **Initialise device**, which fetches the `cmcKey` and tests the connection, then switch it on. Invoices are submitted automatically once an order is paid (or confirmed on credit terms), or manually from the order. Refunds are submitted as credit notes. Invoice numbers have no gaps, as KRA requires, and the invoice PDF prints KRA's signature and verification QR code. Every line is reported under one item that you register in eTIMS.
- **Delivery**: delivery areas with their own fees and ETAs, plus store pickup (Payments & Settings → Business).
- **Discounts**: promo codes (Accounts & Receivables → Promo codes) are validated on the server and can't be read by customers. Business accounts can also get a standing discount.
- **Refunds**: from the order's ⋯ menu. Stripe, PayPal and Flutterwave payments are refunded automatically; M-Pesa, cash and bank refunds are recorded for staff to pay out. You can cancel with a cancellation fee, and a credit note is always issued.
- **Credit terms**: business accounts can pay "on account" with net-X terms and a credit limit. A daily job (06:00 Nairobi time) marks unpaid invoices overdue. The Receivables tab shows aging, statements and a pre-filled WhatsApp reminder.
- **Accounting export**: CSVs of sales (Xero sales-invoice layout, which QuickBooks also imports), payments, refunds and expenses, with a cash-basis profit & loss summary.

## Operations

- **Order history.** `onOrderChanged` records every status, payment, assignment, proof, QC and eTIMS change in `Orders/{id}/Events` with its author. Client order updates must set `lastUpdatedBy` to the signed-in user, and the rules reject any that don't.
- **Production.** Each confirmed order gets a `ProductionJobs/{orderId}` card with a promised date based on lead time in working days. **Manager → Production** has the job board, machine and operator scheduling, a capacity week view (machines are Company Assets with daily hours), and a job sheet PDF with the artwork.
- **Stock.** Each catalog item has a bill of materials. Stock is deducted when an order enters production, restored if it's cancelled, and every change is logged in `InventoryMovements`. Numbered purchase orders ("suggest from low stock", PO PDF) add stock when received and can book the cost as an expense.
- **Quality check.** Nothing reaches *ready for delivery* until `recordQualityCheck` passes the checklist; the rules enforce this.
- **Proof of delivery.** Each order has a secret 4-digit code in `OrderSecrets` that only the customer can read. `completeDelivery` needs that code, or a handover photo plus a signature. Drivers can no longer mark an order delivered directly.
- **Route planning.** Stops are ordered nearest-neighbour + 2-opt from the shop address and opened as a single multi-stop Google Maps route.
- **Audit log.** Triggers record changes to roles, prices, settings, gateways, business accounts, coupons, refunds, manual payments and order moves in `AuditLog`, which is admin-read-only and append-only.

## Growth

- **Notifications (no SMS).** `notifyUser` / `notifyStaff` write to the in-app inbox (`Notifications`, shown behind the bell) and send push (FCM). Email (Resend, SendGrid or Brevo) and WhatsApp (Meta Cloud API template) go out once they're configured under Payments & Settings → Notifications. Web push works in every browser with the project's built-in key; a custom VAPID key under Business settings is optional. Customers choose their channels in their inbox. Triggers cover new orders, status moves, proofs, payments, refunds, overdue invoices, quotes, chat messages, reviews and cart reminders (daily 10:00).
- **Chat.** Each order has a thread in `Orders/{id}/Messages` with photo and PDF attachments and unread counters.
- **Companies.** Accounts & Receivables → Companies & uniforms. Buyers in the same company share the discount, credit limit and terms (credit exposure counts all members' orders). Uniform programs turn a company's past customised lines into approved items; buyers see them on Home and only pick sizes.
- **Checkout.** Saved addresses, a map pin for exact drop-off, and loyalty points (Settings/loyalty) redeemed on the server.
- **Social proof.** Reviews on completed orders are moderated under Manager → Reviews & portfolio; approved ratings roll up onto catalog items. A public "Our work" gallery, plus a wishlist.
- **Referrals.** Codes are created with `getMyReferralCode`. `claimReferral` works before a customer's first order; both sides get bonus points when that first order completes.
- **SEO.** `web/services.html` (crawlable landing page), JSON-LD structured data, `robots.txt`, `sitemap.xml`, and a `<noscript>` fallback.
- **Languages.** English and Kiswahili for everything customers see, switchable in Settings (Auto follows the device).
  - Screen text lives in `lib/l10n/*.arb` (run `flutter gen-l10n`) and is used as `context.l10n.someText`.
  - Fixed choices (categories, statuses, decoration methods, placements, roles) are translated in `lib/core/l10n/enum_l10n.dart` (`.tr(context)`).
  - Server error messages are translated on the device in `lib/core/errors/server_messages.dart`. A new message shows in English until it's added there.
  - Notifications (inbox, push, email, WhatsApp) are sent in the customer's language. The app saves it to `Users/{uid}/Settings/preferences.language`, and `functions/src/notifications/notice_i18n.ts` translates. Its test fails if a customer notice has no Kiswahili.
  - The Terms and Privacy pages have a full Kiswahili version; the English text prevails if they differ.
  - Dates follow the app language.
  - Staff and admin screens are largely English.
- **Currency.** Customers can see approximate prices in other currencies (admin-set rates in Settings/currency); everything is still charged in KES.

## Platform

- **Scales with history.** Staff screens stream a working set: open orders of any age, completed orders still owing money, and the last 120 days. All-time and last-30-day numbers come from counters kept by `aggregateOrderStats` (`Stats/totals`, `Stats/daily-YYYY-MM-DD`). Admin → Dashboard → **Recount** (`rebuildOrderStats`) rebuilds them from every order; run it once after the first deploy. Older orders are found in Manager → History → **Search the full archive**, which is paged and searches `searchKeywords` (order/invoice number, name, company, phone, email) kept by `indexOrderSearch`.
- **Abuse protection.** Every callable requires App Check (`enforceAppCheck`), and the sensitive ones are rate-limited per user (`RateLimits`, auto-deleted by TTL).
- **Offline and weak connections.**
  - A connection monitor (`lib/core/connectivity/`) combines the device's network state with a timed request to `version.json`. It can tell "offline" and "connected but no internet" from "slow".
  - A slim bar at the top of every page (never an overlay) says what's wrong: offline (with **Retry**, and **Open settings** on phones, which opens Android's Internet panel), weak (dismissable), and "Back online".
  - Everything already loaded stays visible: Firestore keeps an offline copy (web: every tab), and photos are cached.
  - On the web, `web/sw.js` keeps the app itself, the Firebase SDK, CanvasKit, fonts and product photos. With no internet the site still opens with its saved data.
  - Actions that need the server say "You're offline. Connect to the internet and try again." Cart, chat, support tickets, wishlist and addresses save on the device and sync when the connection returns.
  - Drivers who confirm a handover with the customer's code while offline have it saved on the phone and sent when the connection returns; the server still checks the code then.
- **Monitoring.** Crashlytics on Android and iOS. Web errors go to `ClientErrors` via `logClientError` (throttled, kept 30 days). Analytics records screen views and the sales funnel (view item, add to cart, begin checkout, purchase, payment, sign-up, login). Firebase Performance collects start-up and network traces.
- **Backups.** `backupFirestore` exports the whole database every night at 02:00 Nairobi time to `gs://bright-brush-firestore-backups`, which keeps 30 days. To restore, run `gcloud firestore import gs://bright-brush-firestore-backups/<date> --database=brightbrush-main`.
- **Branding.** App icons and the launch screen are generated from `assets/branding/` (see `STORE_LISTING.md`). That file also holds the store texts, the data-safety answers and the pre-launch checklist.

## Release process

CI (`.github/workflows/ci.yml`) runs on every push and pull request: analyze, Flutter tests, functions build and tests, rules tests on the emulator, and a web build.

`.github/workflows/deploy.yml` runs after CI:

- **Push to main.** The web app goes to the private `staging` preview channel, so you can check it before customers see it.
- **Actions → Deploy → Run workflow → production.** Deploys functions, then hosting, then rules and indexes.

It needs one repository secret, `FIREBASE_SERVICE_ACCOUNT_PROD`: a JSON key for a service account with these roles:

- Firebase Admin
- Cloud Functions Admin
- Service Account User
- Cloud Scheduler Admin
- Artifact Registry Writer

Until that secret exists, the deploy steps are skipped.

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

## Running locally

App Check is enforced, so debug builds need a registered debug token. Put it in a git-ignored `app_check_debug.json`:

```json
{ "APP_CHECK_DEBUG_TOKEN": "<token from Firebase → App Check → Apps → Manage debug tokens>" }
```

Then run `flutter run --dart-define-from-file=app_check_debug.json` (web, Android or iOS). The same token must be registered on each Firebase app you run. Revoke it in the console if the file leaks.

## Tests

```bash
flutter test                         # app (includes checkout pricing parity with the server)
cd functions && npm test             # pricing, M-Pesa, Stripe, Flutterwave, PayPal helpers
cd rules_tests && npm install && npm test   # security rules on the emulator (needs Java)
```
