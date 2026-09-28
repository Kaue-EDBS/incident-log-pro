export type PeriodKey = "today" | "7d" | "30d" | "month" | "custom";
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
    year: Number(parts["year"]),
    month: Number(parts["month"]),
    day: Number(parts["day"]),
    hour: Number(parts["hour"]),
    minute: Number(parts["minute"]),
    second: Number(parts["second"]),
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
