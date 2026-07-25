/// Normalizes [dt] to midnight UTC of the calendar day its own year/month/day
/// fields represent.
///
/// Every "date" in this app (trip start/end, expense date) means a calendar
/// day, not a specific instant — but Dart's plain `DateTime` (and Drift's
/// default unix-epoch column storage) has no way to represent that: a local
/// `DateTime(2026, 1, 9)` is really "midnight in whatever zone the device
/// happens to be in," and Drift persists it as that absolute instant. Read
/// it back on a device in a different timezone (flew from Berlin to New
/// York) and the stored instant, reinterpreted in local time, lands on a
/// different calendar day — and `Duration`-based day counts silently lose a
/// day across a DST transition even without changing timezone.
///
/// Fix: always normalize to UTC midnight, which has no DST and round-trips
/// through any timezone exactly. `civilDate` is applied twice with different
/// meanings depending on where the DateTime came from:
///  - a **fresh** value (date picker result, `DateTime.now()`) — call it
///    directly; it reads the fields as the intended wall-clock civil date.
///  - a value **read back from persistence** — call `.toUtc()` first so the
///    absolute instant is reinterpreted in UTC (recovering the exact day
///    that was written, regardless of the reading device's timezone), then
///    pass that into `civilDate`.
DateTime civilDate(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);
