/// Pure bill-of-materials maths (no Firebase) for deducting stock when an
/// order goes into production.

export interface MaterialUse {
  materialId: string;
  /// Units of the material consumed per piece (e.g. 0.02 cones of thread,
  /// 1 blank cap).
  perUnit: number;
}

export interface OrderLineForMaterials {
  itemId: string;
  kind: string;
  quantity: number;
  /// Customised lines: pieces per size don't matter for materials, but the
  /// number of decorations does (thread/backing per decoration).
  decorationCount?: number;
}

/// Total material needed for an order: Σ line quantity × perUnit, rounded
/// up to whole stock units (you can't consume 0.4 of a cone from stock).
export function materialNeeds(
  lines: OrderLineForMaterials[],
  boms: Map<string, MaterialUse[]>,
): Map<string, number> {
  const raw = new Map<string, number>();
  for (const line of lines) {
    if (line.kind !== 'item' && line.kind !== 'custom') continue;
    for (const use of boms.get(line.itemId) ?? []) {
      if (!(use.perUnit > 0)) continue;
      raw.set(use.materialId, (raw.get(use.materialId) ?? 0) + line.quantity * use.perUnit);
    }
  }
  const out = new Map<string, number>();
  for (const [id, qty] of raw) {
    // Guard against float noise (e.g. 0.1 * 30 = 3.0000000000000004).
    out.set(id, Math.ceil(Math.round(qty * 1e6) / 1e6));
  }
  return out;
}

export function parseBom(raw: unknown): MaterialUse[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((m: any) => typeof m?.materialId === 'string' && typeof m?.perUnit === 'number' && m.perUnit > 0)
    .map((m: any) => ({ materialId: m.materialId, perUnit: m.perUnit }));
}

/// Promised completion date: order date + the slowest item's lead time
/// (packages and quotes default to a week), skipping Sundays.
export function promisedDate(from: Date, leadTimeDays: number): Date {
  const d = new Date(from.getTime());
  let remaining = Math.max(0, Math.round(leadTimeDays));
  while (remaining > 0) {
    d.setUTCDate(d.getUTCDate() + 1);
    // 0 = Sunday in UTC; Nairobi is UTC+3 so late-evening orders can land
    // a day early — good enough for a promise date.
    if (d.getUTCDay() !== 0) remaining--;
  }
  return d;
}
