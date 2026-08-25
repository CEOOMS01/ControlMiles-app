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

/// Tarifa estándar de millaje del IRS 2026, en centavos por milla.
/// TODO: revisar cada año fiscal — el IRS la publica en otoño para el año
/// siguiente (irs.gov/tax-professionals/standard-mileage-rates).
const double kIrsMileageRateCentsPerMile = 72.5;

double calculateIrsDeductionEstimate(double totalMiles) =>
    (totalMiles * kIrsMileageRateCentsPerMile) / 100.0;
