import { Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { db } from '../core/app';
import { PricedLine } from '../orders/order_writer';
import {
  DECORATION_METHODS,
  DecorationChoice,
  DecorationMethod,
  DecorationPricing,
  LineConfig,
  PLACEMENTS,
  Placement,
  SIZE_CLASSES,
  SizeClass,
  parseDecorationPricing,
  parseItemOptions,
  priceLine,
  validateLine,
} from './pricing';

export async function loadDecorationPricing(
  tx?: Transaction,
): Promise<DecorationPricing> {
  const ref = db.collection('Settings').doc('decoration');
  const snap = tx ? await tx.get(ref) : await ref.get();
  return parseDecorationPricing(snap.data());
}

interface RawDecoration extends DecorationChoice {
  /// Mockup position the customer dragged the design to (0..1 of the
  /// product image) — a reference for production, not priced.
  offsetX?: number;
  offsetY?: number;
}

export interface ParsedCartLine {
  lineId: string;
  itemId: string;
  config: LineConfig & { decorations: RawDecoration[] };
}

const str = (v: unknown, max: number) =>
  typeof v === 'string' ? v.trim().slice(0, max) : '';

function fraction(v: unknown): number | undefined {
  return typeof v === 'number' && Number.isFinite(v)
    ? Math.min(1, Math.max(0, v))
    : undefined;
}

/// Carts/{uid}.lines is written by the client, so every field is parsed
/// defensively; anything malformed becomes a friendly error, never a crash.
export function parseCartLines(raw: unknown): ParsedCartLine[] {
  if (!raw || typeof raw !== 'object') return [];
  return Object.entries(raw as Record<string, any>).map(([lineId, l]) => {
    const bad = () =>
      new HttpsError(
        'failed-precondition',
        'A customised item in your cart is incomplete. Remove it and add it again.',
      );
    if (!l || typeof l !== 'object' || typeof l.itemId !== 'string') throw bad();
    const sizeQuantities: Record<string, number> = {};
    for (const [size, qty] of Object.entries(l.sizeQuantities ?? {})) {
      if (typeof qty === 'number' && qty > 0) {
        sizeQuantities[str(size, 20)] = Math.min(100000, Math.floor(qty));
      }
    }
    const decorations: RawDecoration[] = (Array.isArray(l.decorations) ? l.decorations : [])
      .slice(0, 6)
      .map((d: any) => {
        if (
          !(DECORATION_METHODS as readonly string[]).includes(d?.method) ||
          !(PLACEMENTS as readonly string[]).includes(d?.placement)
        ) {
          throw bad();
        }
        const sizeClass = (SIZE_CLASSES as readonly string[]).includes(d.sizeClass)
          ? (d.sizeClass as SizeClass)
          : 'small';
        return {
          method: d.method as DecorationMethod,
          placement: d.placement as Placement,
          sizeClass,
          ...(typeof d.artworkId === 'string' && d.artworkId ? { artworkId: str(d.artworkId, 100) } : {}),
          ...(str(d.text, 60) ? { text: str(d.text, 60) } : {}),
          threadColours: (Array.isArray(d.threadColours) ? d.threadColours : [])
            .map((c: unknown) => str(c, 30))
            .filter(Boolean)
            .slice(0, 15),
          ...(fraction(d.offsetX) !== undefined ? { offsetX: fraction(d.offsetX) } : {}),
          ...(fraction(d.offsetY) !== undefined ? { offsetY: fraction(d.offsetY) } : {}),
        };
      });
    return {
      lineId: str(lineId, 60),
      itemId: l.itemId,
      config: {
        ...(str(l.colour, 40) ? { colour: str(l.colour, 40) } : {}),
        sizeQuantities,
        decorations,
        names: (Array.isArray(l.names) ? l.names : [])
          .map((n: unknown) => str(n, 40))
          .filter(Boolean)
          .slice(0, 1000),
      },
    };
  });
}

/// Prices customised lines inside the order transaction: loads the catalog
/// items and the caller's own artworks (stitch count / digitized status
/// come from the Artworks docs, never from the client), validates, prices.
/// Performs only reads — safe to call before any transaction writes.
export async function priceCartLines(
  tx: Transaction,
  lines: ParsedCartLine[],
  uid: string,
  pricing: DecorationPricing,
): Promise<PricedLine[]> {
  if (lines.length === 0) return [];
  const itemSnaps = await tx.getAll(
    ...lines.map((l) => db.collection('CatalogItems').doc(l.itemId)),
  );
  const artworkIds = [
    ...new Set(
      lines.flatMap((l) =>
        l.config.decorations.map((d) => d.artworkId).filter((id): id is string => !!id),
      ),
    ),
  ];
  const artworkSnaps = artworkIds.length
    ? await tx.getAll(...artworkIds.map((id) => db.collection('Artworks').doc(id)))
    : [];
  const artworks = new Map(artworkSnaps.map((s) => [s.id, s.data()]));

  return lines.map((line, index) => {
    const snap = itemSnaps[index];
    const d = snap.data();
    if (!snap.exists || !d || d.isActive !== true) {
      throw new HttpsError(
        'failed-precondition',
        'A customised item in your cart is no longer available. Remove it and try again.',
      );
    }
    const options = parseItemOptions(d);
    const decorations = line.config.decorations.map((dec) => {
      if (!dec.artworkId) return dec;
      const art = artworks.get(dec.artworkId);
      if (!art || art.ownerId !== uid) {
        throw new HttpsError(
          'failed-precondition',
          `An artwork used on "${d.name}" is missing. Choose it again.`,
        );
      }
      return {
        ...dec,
        artworkName: String(art.name ?? ''),
        artworkUrl: String(art.fileUrl ?? ''),
        stitchCount: typeof art.stitchCount === 'number' ? art.stitchCount : undefined,
        digitized: art.digitized === true,
      };
    });
    const config: LineConfig = { ...line.config, decorations };
    const problem = validateLine(options, config, pricing);
    if (problem) {
      throw new HttpsError('failed-precondition', `"${d.name}": ${problem}`);
    }
    const price = priceLine(options, config, pricing);
    return {
      kind: 'custom',
      itemId: snap.id,
      name: d.name as string,
      category: (d.category as string) ?? 'other',
      unitPrice: Math.round(price.lineTotal / price.quantity),
      quantity: price.quantity,
      lineTotal: price.lineTotal,
      customization: {
        ...(config.colour ? { colour: config.colour } : {}),
        sizeQuantities: config.sizeQuantities,
        decorations: decorations.map((dec) => stripUndefined({ ...dec })),
        names: config.names,
      },
      pricing: {
        tierUnitPrice: price.tierUnitPrice,
        blankTotal: price.blankTotal,
        decorationPerUnit: price.decorationPerUnit,
        decorationTotal: price.decorationTotal,
        setupFees: price.setupFees,
        personalisationTotal: price.personalisationTotal,
      },
    };
  });
}

function stripUndefined(o: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(o).filter(([, v]) => v !== undefined));
}
