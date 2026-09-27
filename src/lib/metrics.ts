import type { Incident, PeriodKey } from "./types";

export type Range = { from: Date; to: Date };

export const ANALYTICS_TIME_ZONE = "America/Sao_Paulo";

type ZonedParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
};

const analyticsPartsFormatter = new Intl.DateTimeFormat("en-US", {
  timeZone: ANALYTICS_TIME_ZONE,
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
  hourCycle: "h23",
});

function zonedParts(value: Date): ZonedParts {
  const parts = Object.fromEntries(
    analyticsPartsFormatter
      .formatToParts(value)
      .filter((part) => part.type !== "literal")
      .map((part) => [part.type, part.value]),
  );

  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
    second: Number(parts.second),
  };
}

function analyticsOffsetMs(value: Date): number {
  const parts = zonedParts(value);
  const reconstructedUtc = Date.UTC(
    parts.year,
    parts.month - 1,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
  );
  const valueWithoutMs = Math.floor(value.getTime() / 1000) * 1000;
  return reconstructedUtc - valueWithoutMs;
}

export function analyticsLocalDateTimeToUtc(
  year: number,
  month: number,
  day: number,
  hour = 0,
  minute = 0,
  second = 0,
): Date {
  const wallClockAsUtc = Date.UTC(year, month - 1, day, hour, minute, second);
  let candidate = new Date(wallClockAsUtc);

  // Two passes are enough to resolve the IANA offset at the target instant,
  // including historical offset changes represented by Intl.
  for (let i = 0; i < 2; i += 1) {
    const offset = analyticsOffsetMs(candidate);
    candidate = new Date(wallClockAsUtc - offset);
  }

  return candidate;
}

function parseDateOnly(value: string): { year: number; month: number; day: number } | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;
  return { year: Number(match[1]), month: Number(match[2]), day: Number(match[3]) };
}

export function resolveRange(
  period: PeriodKey,
  custom?: { from?: string | undefined; to?: string | undefined },
  now: Date = new Date(),
): Range {
  const to = now;

  if (period === "today") {
    const local = zonedParts(now);
    return {
      from: analyticsLocalDateTimeToUtc(local.year, local.month, local.day),
      to,
    };
  }

  if (period === "7d") return { from: new Date(now.getTime() - 7 * 864e5), to };
  if (period === "30d") return { from: new Date(now.getTime() - 30 * 864e5), to };

  if (period === "month") {
    const local = zonedParts(now);
    return {
      from: analyticsLocalDateTimeToUtc(local.year, local.month, 1),
      to,
    };
  }

  const parsedFrom = custom?.from ? parseDateOnly(custom.from) : null;
  const parsedTo = custom?.to ? parseDateOnly(custom.to) : null;

  const from = parsedFrom
    ? analyticsLocalDateTimeToUtc(parsedFrom.year, parsedFrom.month, parsedFrom.day)
    : new Date(now.getTime() - 30 * 864e5);

  const end = parsedTo
    ? new Date(
        analyticsLocalDateTimeToUtc(parsedTo.year, parsedTo.month, parsedTo.day + 1).getTime() - 1,
      )
    : to;

  return { from, to: end };
}

const MIN = 60000;

export function minutesBetween(a: string | null, b: string | null): number | null {
  if (!a || !b) return null;
  const diff = (new Date(b).getTime() - new Date(a).getTime()) / MIN;
  return diff >= 0 ? diff : null;
}

/** MTTD do incidente: detected_at - failure_started_at */
export function incidentMttd(i: Incident): number | null {
  return minutesBetween(i.failure_started_at, i.detected_at);
}

/** MTTR do incidente: recovered_at - detected_at */
export function incidentMttr(i: Incident): number | null {
  return minutesBetween(i.detected_at, i.recovered_at);
}

/** Downtime: recovered_at - failure_started_at (estimado quando falta failure_started_at) */
export function incidentDowntime(i: Incident): { minutes: number | null; estimated: boolean } {
  if (!i.recovered_at) return { minutes: null, estimated: false };
  if (i.failure_started_at) {
    return { minutes: minutesBetween(i.failure_started_at, i.recovered_at), estimated: false };
  }
  return { minutes: minutesBetween(i.detected_at, i.recovered_at), estimated: true };
}

function avg(values: number[]): number | null {
  if (!values.length) return null;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

function isNum(v: number | null): v is number {
  return v !== null && Number.isFinite(v);
}

/** MTBF por aplicação: próxima failure_started_at - recovered_at anterior */
export function mtbfForApplication(incidents: Incident[]): number | null {
  const ordered = [...incidents]
    .filter((i) => i.recovered_at)
    .sort((a, b) => new Date(a.detected_at).getTime() - new Date(b.detected_at).getTime());
  const gaps: number[] = [];
  for (let i = 1; i < ordered.length; i++) {
    const prev = ordered[i - 1]!;
    const next = ordered[i]!;
    const start = next.failure_started_at ?? next.detected_at;
    const gap = minutesBetween(prev.recovered_at, start);
    if (isNum(gap)) gaps.push(gap);
  }
  return avg(gaps);
}

export type Metrics = {
  count: number;
  mttd: number | null;
  mttr: number | null;
  mtbf: number | null;
  downtime: number;
  downtimeEstimated: boolean;
  availability: number;
};

/** Métricas agregadas. MTBF é sempre calculado por aplicação e depois consolidado. */
export function computeMetrics(incidents: Incident[], range: Range): Metrics {
  const mttds = incidents.map(incidentMttd).filter(isNum);
  const mttrs = incidents.filter((i) => i.status === "resolved").map(incidentMttr).filter(isNum);

  let downtime = 0;
  let estimated = false;
  for (const i of incidents) {
    const d = incidentDowntime(i);
    if (isNum(d.minutes)) {
      downtime += d.minutes;
      if (d.estimated) estimated = true;
    } else if (i.status === "active") {
      const start = i.failure_started_at ?? i.detected_at;
      downtime += Math.max(0, (Date.now() - new Date(start).getTime()) / MIN);
      estimated = true;
    }
  }

  const byApp = new Map<string, Incident[]>();
  for (const i of incidents) {
    const list = byApp.get(i.application_id) ?? [];
    list.push(i);
    byApp.set(i.application_id, list);
  }
  const mtbfs = [...byApp.values()].map(mtbfForApplication).filter(isNum);

  const totalMinutes = Math.max(1, (range.to.getTime() - range.from.getTime()) / MIN);
  const availability = Math.max(0, Math.min(100, ((totalMinutes - downtime) / totalMinutes) * 100));

  return {
    count: incidents.length,
    mttd: avg(mttds),
    mttr: avg(mttrs),
    mtbf: avg(mtbfs),
    downtime,
    downtimeEstimated: estimated,
    availability,
  };
}

export function formatMinutes(value: number | null | undefined): string {
  if (value === null || value === undefined || !Number.isFinite(value)) return "—";
  const total = Math.round(value);
  if (total < 60) return `${total} min`;
  const h = Math.floor(total / 60);
  const m = total % 60;
  if (h < 24) return m ? `${h}h ${m}min` : `${h}h`;
  const d = Math.floor(h / 24);
  return `${d}d ${h % 24}h`;
}

export function formatDuration(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${pad(h)}:${pad(m)}:${pad(s)}`;
}

export function formatDateTime(value: string | null): string {
  if (!value) return "—";
  return new Date(value).toLocaleString("pt-BR", {
    timeZone: ANALYTICS_TIME_ZONE,
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function toLocalInput(value: string | null): string {
  if (!value) return "";
  const parts = zonedParts(new Date(value));
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${parts.year}-${pad(parts.month)}-${pad(parts.day)}T${pad(parts.hour)}:${pad(parts.minute)}`;
}

export function analyticsLocalInputToIso(value: string): string | null {
  if (!value) return null;
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/.exec(value);
  if (!match) return null;

  return analyticsLocalDateTimeToUtc(
    Number(match[1]),
    Number(match[2]),
    Number(match[3]),
    Number(match[4]),
    Number(match[5]),
    Number(match[6] ?? "0"),
  ).toISOString();
}
