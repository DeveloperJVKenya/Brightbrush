import { HttpsError } from 'firebase-functions/v2/https';

import { optionalString, requireEnum, requireString } from '../core/validate';
import { BusinessSettings } from '../settings/business_settings';
import { OrderContact } from './order_writer';

export interface Fulfilment {
  method: 'delivery' | 'pickup';
  zoneId?: string;
  zoneName?: string;
  etaDays?: number;
  /// Zone fee, or undefined to use the flat fee.
  deliveryFee?: number;
}

/// Delivery (to a configured zone) or store pickup, validated against the
/// admin's Settings/business options.
export function readFulfilment(
  data: Record<string, unknown>,
  settings: BusinessSettings,
): Fulfilment {
  const method = requireEnum(data, 'deliveryMethod', ['delivery', 'pickup'], 'delivery');
  if (method === 'pickup') {
    if (!settings.allowPickup) {
      throw new HttpsError('failed-precondition', 'Store pickup isn\'t available right now.');
    }
    return { method };
  }
  if (settings.deliveryZones.length === 0) return { method };
  const zoneId = typeof data.deliveryZoneId === 'string' ? data.deliveryZoneId : '';
  const zone = settings.deliveryZones.find((z) => z.id === zoneId);
  if (!zone) {
    throw new HttpsError('invalid-argument', 'Choose your delivery area.');
  }
  return {
    method,
    zoneId: zone.id,
    zoneName: zone.name,
    etaDays: zone.etaDays,
    deliveryFee: zone.fee,
  };
}

export function readContact(
  data: Record<string, unknown>,
  options: { pickup?: boolean; pickupAddress?: string } = {},
): OrderContact {
  const typedAddress = optionalString(data, 'deliveryAddress', 'Delivery address', 300);
  if (!options.pickup && typedAddress.length < 5) {
    throw new HttpsError('invalid-argument', 'Enter a delivery address.');
  }
  return {
    contactName: requireString(data, 'contactName', 'Contact name', 2, 80),
    contactPhone: requireString(data, 'contactPhone', 'Contact phone', 3, 30),
    deliveryAddress: options.pickup
      ? `Pickup${options.pickupAddress ? ` at ${options.pickupAddress}` : ''}`.slice(0, 300)
      : typedAddress,
    notes: optionalString(data, 'notes', 'Notes', 1000),
  };
}

export function fulfilmentFields(f: Fulfilment): Record<string, unknown> {
  return {
    deliveryMethod: f.method,
    ...(f.zoneId ? { deliveryZoneId: f.zoneId, deliveryZoneName: f.zoneName } : {}),
  };
}
