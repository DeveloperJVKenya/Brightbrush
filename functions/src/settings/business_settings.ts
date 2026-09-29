import { db } from '../core/app';
import { PricingSettings } from '../orders/pricing';

/// Settings/business — editable by Admin/CEO in Payments & Settings,
/// readable by everyone (checkout shows the same VAT/delivery/deposit
/// preview the server computes). Every field has a safe default so a fresh
/// project works before anyone opens the settings screen.
export interface DeliveryZone {
  id: string;
  name: string;
  fee: number;
  etaDays: number;
}

export interface BusinessSettings extends PricingSettings {
  businessName: string;
  /// Printed on invoices/receipts.
  physicalAddress: string;
  /// Bank / Paybill details printed on invoices for offline payment.
  paymentInstructions: string;
  invoiceFooter: string;
  /// Checkout options. With no zones, the flat delivery fee applies.
  deliveryZones: DeliveryZone[];
  allowPickup: boolean;
  pickupAddress: string;
  appBaseUrl: string;
  supportPhone: string;
  supportEmail: string;
  kraPin: string;
}

export const DEFAULT_BUSINESS_SETTINGS: BusinessSettings = {
  businessName: 'BrightBrush Creations',
  physicalAddress: '',
  paymentInstructions: '',
  invoiceFooter: 'Thank you for your business.',
  deliveryZones: [],
  allowPickup: false,
  pickupAddress: '',
  appBaseUrl: 'https://bright-brush.web.app',
  supportPhone: '',
  supportEmail: '',
  kraPin: '',
  vatEnabled: false,
  vatRate: 0.16,
  pricesIncludeVat: true,
  deliveryFlatFee: 0,
  freeDeliveryThreshold: 0,
  allowDeposit: true,
  depositPercent: 50,
};

function num(value: unknown, fallback: number, min: number, max: number) {
  return typeof value === 'number' && value >= min && value <= max
    ? value
    : fallback;
}

function str(value: unknown, fallback: string) {
  return typeof value === 'string' && value.trim() ? value.trim() : fallback;
}

function bool(value: unknown, fallback: boolean) {
  return typeof value === 'boolean' ? value : fallback;
}

export async function loadBusinessSettings(): Promise<BusinessSettings> {
  const snap = await db.collection('Settings').doc('business').get();
  const d = snap.data() ?? {};
  const f = DEFAULT_BUSINESS_SETTINGS;
  return {
    businessName: str(d.businessName, f.businessName),
    physicalAddress: str(d.physicalAddress, f.physicalAddress),
    paymentInstructions: str(d.paymentInstructions, f.paymentInstructions),
    invoiceFooter: str(d.invoiceFooter, f.invoiceFooter),
    deliveryZones: (Array.isArray(d.deliveryZones) ? d.deliveryZones : [])
      .filter((z: any) => typeof z?.id === 'string' && typeof z?.name === 'string')
      .map((z: any) => ({
        id: z.id,
        name: z.name,
        fee: num(z.fee, 0, 0, 1e7),
        etaDays: num(z.etaDays, 0, 0, 365),
      })),
    allowPickup: bool(d.allowPickup, f.allowPickup),
    pickupAddress: str(d.pickupAddress, f.pickupAddress),
    appBaseUrl: str(d.appBaseUrl, f.appBaseUrl).replace(/\/+$/, ''),
    supportPhone: str(d.supportPhone, f.supportPhone),
    supportEmail: str(d.supportEmail, f.supportEmail),
    kraPin: str(d.kraPin, f.kraPin),
    vatEnabled: bool(d.vatEnabled, f.vatEnabled),
    vatRate: num(d.vatRate, f.vatRate, 0, 1),
    pricesIncludeVat: bool(d.pricesIncludeVat, f.pricesIncludeVat),
    deliveryFlatFee: num(d.deliveryFlatFee, f.deliveryFlatFee, 0, 1e7),
    freeDeliveryThreshold: num(
      d.freeDeliveryThreshold,
      f.freeDeliveryThreshold,
      0,
      1e9,
    ),
    allowDeposit: bool(d.allowDeposit, f.allowDeposit),
    depositPercent: num(d.depositPercent, f.depositPercent, 0, 100),
  };
}

/// Where a customer lands after a hosted checkout (Stripe/PayPal/
/// Flutterwave). The Flutter web app uses the default hash URL strategy.
export function orderPageUrl(
  settings: BusinessSettings,
  orderId: string,
  outcome: 'success' | 'cancelled' | 'failed',
): string {
  return `${settings.appBaseUrl}/#/customer/orders/${orderId}?payment=${outcome}`;
}
