// Olympus Mont Systems LLC - ControlMiles
// lib/data/irs_rates.dart
//
// Fuente única de la tarifa estándar de millaje del IRS. Antes vivía
// hardcodeada y privada dentro de report_service.dart
// (_kIrsRateCentsPerMile) — el PDF de reportes ya mostraba una cifra de
// "DEDUCTION:" calculada con ese valor, sin ningún disclaimer. Ahora el PDF
// y el badge de millas del Dashboard leen el mismo valor desde acá, para no
// repetir el problema de "dos copias que se desincronizan" (ver
// GigAppCatalog / color de Custom-Truck, mismo error de este sesión).
//
// REAL BUG FIX (2026-08-28, confirmed live against irs.gov): the IRS split
// the 2026 standard mileage rate mid-year -- 72.5c/mile for travel Jan 1
// through Jun 30, 76c/mile from Jul 1 on (first mid-year change since
// 2022). "The rate that applies depends on the date you drove, not the
// date you file or reimburse" (irs.gov/tax-professionals/standard-mileage-
// rates). This file used to expose a single flat rate applied to every
// trip regardless of date -- every deduction estimate shown since Jul 1
// 2026 was silently understated. Every call site now must pass the real
// drive date; there is no rate-agnostic entry point left to accidentally
// fall back to the stale flat value.

/// Standard mileage rate, Jan 1 - Jun 30, 2026, in cents per mile.
const double kIrsMileageRateCentsPerMile2026H1 = 72.5;

/// Standard mileage rate, Jul 1 - Dec 31, 2026, in cents per mile.
const double kIrsMileageRateCentsPerMile2026H2 = 76.0;

final DateTime _rateChange2026 = DateTime.utc(2026, 7, 1);

/// The rate that applied on [driveDate], in cents per mile.
/// TODO: revisar cada año fiscal -- el IRS la publica en otoño para el año
/// siguiente (irs.gov/tax-professionals/standard-mileage-rates). Cualquier
/// fecha fuera de 2026 hoy cae en la tarifa conocida más cercana (H1 para
/// años anteriores, H2 para 2027 en adelante) hasta que se agregue la
/// tarifa real de ese año.
double ratePerMileCentsForDate(DateTime driveDate) {
  final d = driveDate.toUtc();
  if (d.isBefore(_rateChange2026)) return kIrsMileageRateCentsPerMile2026H1;
  return kIrsMileageRateCentsPerMile2026H2;
}

/// Estimated deduction for a single trip/session, using the rate that
/// actually applied on [driveDate] -- never a flat year-round rate.
double calculateIrsDeductionEstimate(double miles, DateTime driveDate) =>
    (miles * ratePerMileCentsForDate(driveDate)) / 100.0;

/// Sums the deduction across many dated trips, each priced at the rate
/// that applied on ITS OWN drive date -- the only correct way to total a
/// period (a badge's year-to-date figure, a report spanning the Jul 1
/// boundary) that doesn't silently misprice half the trips.
double calculateIrsDeductionEstimateForTrips(
  Iterable<({double miles, DateTime date})> trips,
) {
  double total = 0.0;
  for (final t in trips) {
    total += calculateIrsDeductionEstimate(t.miles, t.date);
  }
  return total;
}
