import {
  ANALYTICS_TIME_ZONE,
  analyticsLocalInputToIso,
  formatDateTime,
  resolveRange,
  toLocalInput,
} from "../../src/lib/metrics";

function assertEqual(actual: unknown, expected: unknown, label: string) {
  if (actual !== expected) {
    throw new Error(`${label}: expected ${String(expected)}, got ${String(actual)}`);
  }
  console.log(`PASS ${label}: ${String(actual)}`);
}

assertEqual(ANALYTICS_TIME_ZONE, "America/Sao_Paulo", "canonical analytics timezone");

const storedInstant = "2026-09-28T01:30:00.000Z";
assertEqual(
  toLocalInput(storedInstant),
  "2026-09-27T22:30",
  "UTC instant renders as Sao Paulo datetime-local",
);

assertEqual(
  analyticsLocalInputToIso("2026-09-27T22:30"),
  storedInstant,
  "Sao Paulo datetime-local round-trips to the original UTC instant",
);

const formatted = formatDateTime(storedInstant);
if (!formatted.includes("27/09/2026") || !formatted.includes("22:30")) {
  throw new Error(`formatted analytics datetime is not Sao Paulo local time: ${formatted}`);
}
console.log(`PASS formatted analytics datetime: ${formatted}`);

const now = new Date(storedInstant);
const today = resolveRange("today", undefined, now);
assertEqual(
  today.from.toISOString(),
  "2026-09-27T03:00:00.000Z",
  "today starts at Sao Paulo midnight",
);
assertEqual(today.to.toISOString(), storedInstant, "today ends at supplied current instant");

const month = resolveRange("month", undefined, now);
assertEqual(
  month.from.toISOString(),
  "2026-09-01T03:00:00.000Z",
  "month starts at Sao Paulo local month boundary",
);

const custom = resolveRange("custom", { from: "2026-09-27", to: "2026-09-27" }, now);
assertEqual(
  custom.from.toISOString(),
  "2026-09-27T03:00:00.000Z",
  "custom range starts at Sao Paulo midnight",
);
assertEqual(
  custom.to.toISOString(),
  "2026-09-28T02:59:59.999Z",
  "custom range ends at Sao Paulo local end-of-day",
);

console.log("C07 analytics timezone smoke PASS");
