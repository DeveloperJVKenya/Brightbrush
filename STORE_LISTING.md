# Store listing kit

Everything needed to publish BrightBrush on Google Play and the App Store. Copy the texts as they are, or adjust them to your voice.

## Before the first upload

1. **Change the app ID.** Android still uses `com.example.brightbrush`, and Google Play rejects any `com.example.*` ID. Pick a permanent ID such as `ke.co.brightbrush.app`. Changing it later means publishing a new app.
   - Set it as `namespace` and `applicationId` in `android/app/build.gradle.kts`, and as the iOS bundle identifier in Xcode.
   - Register the new IDs in Firebase Console → Project settings → Add app. Then run `flutterfire configure` to regenerate `lib/firebase_options.dart`, `google-services.json` and `GoogleService-Info.plist`.
   - Register the Android app in App Check (Play Integrity) and the iOS app in App Check (App Attest). The callables enforce App Check, so an unregistered app can't place orders.
2. **Release signing.** Create an upload keystore, reference it from `android/key.properties`, and enrol in Play App Signing.
3. **Replace the icon.** `assets/branding/*.png` holds a placeholder "BB" mark in the brand colours. Put the real logo there, then run:
   ```bash
   dart run flutter_launcher_icons
   dart run flutter_native_splash:create
   ```
4. **Crashlytics dSYMs (iOS).** Add the Crashlytics upload-symbols run script in Xcode so iOS crash reports are readable.

## Listing text

**App name (30):** BrightBrush Creations

**Short description (80):** Custom embroidery & branding in Kenya. Design, approve, pay with M-Pesa, track.

**Full description:**

> Get caps, T-shirts, hoodies, polos, bottles, bags and uniforms embroidered or printed with your logo, without the back-and-forth.
>
> • **Design it yourself.** Pick an item, upload your logo, choose where it goes and see a live preview.
> • **Approve before we stitch.** We send a digital proof. Approve it or request changes in the app.
> • **Pay your way.** M-Pesa (STK push), card, PayPal or Flutterwave. You can pay a deposit now and the balance later, and businesses can buy on credit terms.
> • **Track every step.** Confirmed, in production, quality-checked, out for delivery. You get notified at each stage.
> • **Proof of delivery.** Your driver hands over only against your secret 4-digit code.
> • **Company & uniform programs.** Staff order from your approved catalogue and you get one monthly invoice.
> • **KRA eTIMS invoices**, receipts and statements, downloadable any time.
> • **Chat with us** in the app or on WhatsApp, in English or Kiswahili.
> • **Earn points** on every order and for referring friends.
>
> Bulk quotes for schools, churches, events, SACCOs and corporates: request one in the app and accept it in one tap.

**Category:** Shopping (Play) / Business or Shopping (App Store)
**Tags / keywords:** embroidery, branding, custom t-shirts, merchandise, uniforms, printing, Kenya, Nairobi, M-Pesa, corporate gifts
**Contact:** use the support email and phone from Admin → Business settings
**Privacy policy URL:** `https://bright-brush.web.app/#/legal/privacy`
**Terms URL:** `https://bright-brush.web.app/#/legal/terms`
**Account deletion URL** (Play requirement): `https://bright-brush.web.app/#/legal/privacy`. Customers can also delete their account in the app under Profile → Delete my account.

## Screenshots to capture

Phone screenshots: 1080×1920 or larger, at least 4 and up to 8. Tablet screenshots: 7" and 10". Capture them from a customer account with real products:

1. Catalogue home with categories and featured items
2. Branding configurator with a logo placed on a cap or T-shirt (live preview)
3. Proof approval screen
4. Checkout with M-Pesa selected, and deposit / full options
5. Order tracking timeline
6. Order chat or WhatsApp button
7. Rewards card (points and referral code)
8. Invoice or receipt PDF

**Feature graphic (Play, 1024×500):** the brand gradient (#D8232B → #3A1620), the logo, and the line "Your logo, on anything."

## Google Play data safety form

| Data type | Collected | Shared | Purpose | Optional? |
| --- | --- | --- | --- | --- |
| Name | Yes | No | Account, orders, delivery | Required |
| Email address | Yes | No | Account, receipts, notifications | Required |
| Phone number | Yes | With payment providers (M-Pesa etc.) only to take payment | Delivery contact, payments | Required to order |
| Physical address | Yes | No | Delivery | Required for delivery orders |
| Approximate/precise location | Yes, only when you drop a delivery pin, and from drivers at handover | No | Delivery | Optional |
| Photos (uploaded artwork, handover photos) | Yes | No | Product customisation, proof of delivery | Optional |
| Purchase history | Yes | No | Orders, invoices, loyalty | Required |
| Payment info | **No.** Card and wallet details are entered on the provider's page (Stripe, PayPal, Flutterwave) or in M-Pesa | n/a | n/a | n/a |
| Messages (order chat, support) | Yes | No | Customer support | Optional |
| Crash logs & diagnostics | Yes | No (Google Firebase processes them for us) | App stability | Required |
| App interactions (analytics) | Yes | No | Analytics | Required |
| Device IDs (push token) | Yes | No | Notifications | Optional |

- Data is encrypted in transit: **Yes**.
- Users can request deletion: **Yes**, in the app (Profile → Delete my account) or by email.
- Independent security review: No.
- Target audience: 18+. The app is not designed for children.

## App Store privacy ("nutrition label")

- **Data linked to you:** Contact info (name, email, phone, address), Purchases, User content (photos, messages), Identifiers (user ID), Location (precise, optional).
- **Data not linked to you:** Diagnostics (crash data, performance), Usage data (analytics).
- **Tracking:** None. There is no cross-app tracking and no advertising SDKs.

## Review notes (paste into the reviewer notes field)

> Browsing the catalogue needs no account. To test ordering, sign in with the demo customer:
> `review@brightbrush.test` / *(create this account before submitting and put its password here)*.
> To review payments without a real charge, switch the gateway to test/sandbox mode in Admin → Payment gateways while the review runs, or choose M-Pesa and cancel the prompt on the phone.
