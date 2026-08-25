// Olympus Mont Systems LLC - ControlMiles
// lib/data/vehicle_makes.dart
//
// Lista fija de marcas comunes para el dropdown de "marca" del vehículo.
// Objetivo: consistencia en la columna `vehicles.make` — sin esto, el
// mismo fabricante termina guardado como "toyota", "Toyota" y "TOYOTA" en
// filas distintas. "Otra" al final habilita un campo de texto libre para
// marcas no listadas (motos, camiones especializados, etc.) sin bloquear
// al usuario.

const String kOtherVehicleMake = 'Otra';

const List<String> kVehicleMakes = [
  'Toyota',
  'Nissan',
  'Honda',
  'Ford',
  'Chevrolet',
  'Jeep',
  'Hyundai',
  'Kia',
  'RAM',
  'GMC',
  'Dodge',
  'Chrysler',
  'Volkswagen',
  'BMW',
  'Mercedes-Benz',
  'Audi',
  'Subaru',
  'Mazda',
  'Lexus',
  'Acura',
  'Infiniti',
  'Buick',
  'Cadillac',
  'Lincoln',
  'Volvo',
  'Mitsubishi',
  'Tesla',
  'Mini',
  'Fiat',
  'Land Rover',
  'Jaguar',
  'Porsche',
  'Genesis',
  'Alfa Romeo',
  'Freightliner',
  'International',
  'Isuzu',
  'Peterbilt',
  'Kenworth',
  kOtherVehicleMake,
];
