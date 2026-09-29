/// Pure pricing for customised (decorated) catalog lines — no Firebase
/// imports, so it's unit-testable. Mirrored in Dart by
/// lib/features/customization/domain/customization_pricing.dart (checkout
/// preview only); this server copy is what orders are actually charged.

export const DECORATION_METHODS = [
  'embroidery',
  'screenPrint',
  'dtf',
  'heatTransfer',
  'sublimation',
  'laserEngraving',
] as const;
export type DecorationMethod = (typeof DECORATION_METHODS)[number];

export const PLACEMENTS = [
  'leftChest',
  'rightChest',
  'centerChest',
  'fullFront',
  'upperBack',
  'fullBack',
  'leftSleeve',
  'rightSleeve',
  'capFront',
  'capSide',
  'capBack',
  'productFront',
  'productBack',
  'wrapAround',
] as const;
export type Placement = (typeof PLACEMENTS)[number];

/// Design size bands: small ≤ 10 cm, medium ≤ 20 cm, large ≤ 30 cm.
export const SIZE_CLASSES = ['small', 'medium', 'large'] as const;
export type SizeClass = (typeof SIZE_CLASSES)[number];

export interface MethodPricing {
  enabled: boolean;
  /// One-off per design per order (digitizing for embroidery, screens for
  /// screen print, jig setup for laser engraving).
  setupFee: number;
  perUnit: Record<SizeClass, number>;
  /// Embroidery only: once a logo is digitized its exact stitch count is
  /// known, and the per-piece price becomes ceil(stitches / 1000) × this.
  per1000Stitches: number;
}

export interface DecorationPricing {
  methods: Record<DecorationMethod, MethodPricing>;
  /// Per personalised piece (e.g. a staff name on each shirt).
  personalisationFee: number;
}

export interface PriceTier {
  minQty: number;
  unitPrice: number;
}

export interface SizeOption {
  label: string;
  surcharge: number;
}

export interface ItemOptions {
  basePrice: number;
  moq: number;
  priceTiers: PriceTier[];
  sizes: SizeOption[];
  colours: string[];
  decorationMethods: DecorationMethod[];
  placements: Placement[];
}

export interface DecorationChoice {
  method: DecorationMethod;
  placement: Placement;
  sizeClass: SizeClass;
  artworkId?: string;
  text?: string;
  threadColours: string[];
  /// Filled in from the Artworks doc server-side, never from the client.
  stitchCount?: number;
  digitized?: boolean;
}

export interface LineConfig {
  colour?: string;
  /// Size label → pieces. Items without sizes use the single key ONE_SIZE.
  sizeQuantities: Record<string, number>;
  decorations: DecorationChoice[];
  names: string[];
}

export const ONE_SIZE = 'One size';

export interface LinePrice {
  quantity: number;
  tierUnitPrice: number;
  blankTotal: number;
  decorationPerUnit: number;
  decorationTotal: number;
  setupFees: number;
  personalisationTotal: number;
  lineTotal: number;
}

export function totalQuantity(config: LineConfig): number {
  return Object.values(config.sizeQuantities).reduce(
    (s, q) => s + (Number.isFinite(q) && q > 0 ? Math.floor(q) : 0),
    0,
  );
}

/// The blank's unit price for this quantity: the highest tier the order
/// reaches, else the base price.
export function tierPrice(item: ItemOptions, quantity: number): number {
  let price = item.basePrice;
  let best = 0;
  for (const tier of item.priceTiers) {
    if (quantity >= tier.minQty && tier.minQty >= best && tier.unitPrice > 0) {
      best = tier.minQty;
      price = tier.unitPrice;
    }
  }
  return price;
}

export function decorationUnitPrice(
  choice: DecorationChoice,
  pricing: DecorationPricing,
): number {
  const method = pricing.methods[choice.method];
  if (
    choice.method === 'embroidery' &&
    choice.stitchCount &&
    choice.stitchCount > 0 &&
    method.per1000Stitches > 0
  ) {
    return Math.ceil(choice.stitchCount / 1000) * method.per1000Stitches;
  }
  return method.perUnit[choice.sizeClass];
}

/// Returns a customer-facing reason the line can't be ordered, or null.
export function validateLine(
  item: ItemOptions,
  config: LineConfig,
  pricing: DecorationPricing,
): string | null {
  const quantity = totalQuantity(config);
  if (quantity <= 0) return 'Enter how many pieces you need.';
  if (quantity < item.moq) {
    return `The minimum order is ${item.moq} pieces (you have ${quantity}).`;
  }
  const allowedSizes = item.sizes.length
    ? item.sizes.map((s) => s.label)
    : [ONE_SIZE];
  for (const [size, qty] of Object.entries(config.sizeQuantities)) {
    if (qty > 0 && !allowedSizes.includes(size)) {
      return `Size "${size}" isn't available for this item.`;
    }
  }
  if (item.colours.length && (!config.colour || !item.colours.includes(config.colour))) {
    return 'Choose one of the available colours.';
  }
  if (config.decorations.length > 6) return 'At most 6 decorations per item.';
  const used = new Set<string>();
  for (const d of config.decorations) {
    if (!item.decorationMethods.includes(d.method)) {
      return 'That decoration method isn\'t offered on this item.';
    }
    if (!pricing.methods[d.method]?.enabled) {
      return 'That decoration method is currently unavailable.';
    }
    if (!item.placements.includes(d.placement)) {
      return 'That placement isn\'t offered on this item.';
    }
    if (used.has(d.placement)) return 'Each placement can only be used once.';
    used.add(d.placement);
    if (!d.artworkId && !(d.text ?? '').trim()) {
      return 'Each decoration needs artwork or text.';
    }
  }
  if (config.names.length > quantity) {
    return 'You have more names than pieces.';
  }
  return null;
}

export function priceLine(
  item: ItemOptions,
  config: LineConfig,
  pricing: DecorationPricing,
): LinePrice {
  const quantity = totalQuantity(config);
  const tierUnitPrice = tierPrice(item, quantity);
  const surcharge = new Map(item.sizes.map((s) => [s.label, s.surcharge]));
  let blankTotal = 0;
  for (const [size, raw] of Object.entries(config.sizeQuantities)) {
    const qty = raw > 0 ? Math.floor(raw) : 0;
    blankTotal += qty * (tierUnitPrice + (surcharge.get(size) ?? 0));
  }

  let decorationPerUnit = 0;
  let setupFees = 0;
  const setupCharged = new Set<string>();
  for (const d of config.decorations) {
    decorationPerUnit += decorationUnitPrice(d, pricing);
    // The same design in the same method is set up once per order line
    // (e.g. one logo on both sleeves); embroidery digitizing is waived
    // when the artwork has already been digitized.
    const key = `${d.method}:${d.artworkId ?? `text:${(d.text ?? '').trim()}`}`;
    const waived = d.method === 'embroidery' && d.digitized === true;
    if (!waived && !setupCharged.has(key)) {
      setupCharged.add(key);
      setupFees += pricing.methods[d.method].setupFee;
    }
  }

  const decorationTotal = decorationPerUnit * quantity;
  const personalisationTotal =
    config.names.filter((n) => n.trim()).length * pricing.personalisationFee;
  const lineTotal = Math.round(
    blankTotal + decorationTotal + setupFees + personalisationTotal,
  );
  return {
    quantity,
    tierUnitPrice,
    blankTotal: Math.round(blankTotal),
    decorationPerUnit,
    decorationTotal: Math.round(decorationTotal),
    setupFees: Math.round(setupFees),
    personalisationTotal: Math.round(personalisationTotal),
    lineTotal,
  };
}

export const DEFAULT_DECORATION_PRICING: DecorationPricing = {
  personalisationFee: 200,
  methods: {
    embroidery: { enabled: true, setupFee: 1500, perUnit: { small: 150, medium: 300, large: 600 }, per1000Stitches: 40 },
    screenPrint: { enabled: true, setupFee: 2000, perUnit: { small: 80, medium: 150, large: 250 }, per1000Stitches: 0 },
    dtf: { enabled: true, setupFee: 0, perUnit: { small: 120, medium: 200, large: 350 }, per1000Stitches: 0 },
    heatTransfer: { enabled: true, setupFee: 0, perUnit: { small: 100, medium: 180, large: 300 }, per1000Stitches: 0 },
    sublimation: { enabled: true, setupFee: 0, perUnit: { small: 150, medium: 250, large: 400 }, per1000Stitches: 0 },
    laserEngraving: { enabled: true, setupFee: 500, perUnit: { small: 100, medium: 150, large: 250 }, per1000Stitches: 0 },
  },
};

/// Parses an untrusted map (Firestore doc or client payload) into
/// DecorationPricing, falling back to the defaults field by field.
export function parseDecorationPricing(raw: unknown): DecorationPricing {
  const d = (raw && typeof raw === 'object' ? raw : {}) as Record<string, any>;
  const num = (v: unknown, fallback: number) =>
    typeof v === 'number' && Number.isFinite(v) && v >= 0 && v <= 1e7 ? v : fallback;
  const methods = {} as Record<DecorationMethod, MethodPricing>;
  for (const m of DECORATION_METHODS) {
    const f = DEFAULT_DECORATION_PRICING.methods[m];
    const r = (d.methods?.[m] ?? {}) as Record<string, any>;
    methods[m] = {
      enabled: typeof r.enabled === 'boolean' ? r.enabled : f.enabled,
      setupFee: num(r.setupFee, f.setupFee),
      perUnit: {
        small: num(r.perUnit?.small, f.perUnit.small),
        medium: num(r.perUnit?.medium, f.perUnit.medium),
        large: num(r.perUnit?.large, f.perUnit.large),
      },
      per1000Stitches: num(r.per1000Stitches, f.per1000Stitches),
    };
  }
  return {
    methods,
    personalisationFee: num(d.personalisationFee, DEFAULT_DECORATION_PRICING.personalisationFee),
  };
}

/// Parses a CatalogItems doc's customisation fields.
export function parseItemOptions(d: Record<string, any>): ItemOptions {
  const tiers = Array.isArray(d.priceTiers) ? d.priceTiers : [];
  const sizes = Array.isArray(d.sizes) ? d.sizes : [];
  return {
    basePrice: typeof d.basePrice === 'number' ? d.basePrice : 0,
    moq: typeof d.moq === 'number' && d.moq > 0 ? d.moq : 1,
    priceTiers: tiers
      .filter((t: any) => typeof t?.minQty === 'number' && typeof t?.unitPrice === 'number')
      .map((t: any) => ({ minQty: t.minQty, unitPrice: t.unitPrice })),
    sizes: sizes
      .filter((s: any) => typeof s?.label === 'string' && s.label)
      .map((s: any) => ({
        label: s.label,
        surcharge: typeof s.surcharge === 'number' ? s.surcharge : 0,
      })),
    colours: Array.isArray(d.colours)
      ? d.colours.map((c: any) => (typeof c === 'string' ? c : c?.name)).filter(Boolean)
      : [],
    decorationMethods: (Array.isArray(d.decorationMethods) ? d.decorationMethods : []).filter(
      (m: string) => (DECORATION_METHODS as readonly string[]).includes(m),
    ),
    placements: (Array.isArray(d.placements) ? d.placements : []).filter((p: string) =>
      (PLACEMENTS as readonly string[]).includes(p),
    ),
  };
}
