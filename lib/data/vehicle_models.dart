// Olympus Mont Systems LLC - ControlMiles
// lib/data/vehicle_models.dart
//
// Modelos comunes por marca, para que "modelo" se elija igual que se elige
// "marca" en vez de escribirse. Mismo objetivo que vehicle_makes.dart: sin
// esto la columna `vehicles.model` acumula "corolla", "Corolla", "COROLLA" y
// "Corola" como valores distintos del mismo coche.
//
// La lista es deliberadamente de modelos COMUNES, no exhaustiva. Un catálogo
// completo por año y submodelo sería enorme, quedaría desactualizado cada
// temporada y no aporta nada a un registro de millaje: lo que importa es que
// el mismo vehículo se escriba siempre igual. kOtherVehicleModel cubre el
// resto sin bloquear a nadie, exactamente como kOtherVehicleMake.
//
// Las claves son los literales de kVehicleMakes. Una marca sin entrada aquí
// (o la marca libre "Otra") cae a campo de texto: ver _modelsForSelectedMake
// en vehicle_screen.dart.

const String kOtherVehicleModel = 'Otro';

const Map<String, List<String>> kVehicleModelsByMake = {
  'Toyota': [
    'Corolla', 'Camry', 'RAV4', 'Highlander', 'Tacoma', 'Tundra', 'Prius',
    'Sienna', '4Runner', 'Sequoia', 'Avalon', 'Yaris', 'C-HR', 'Venza',
  ],
  'Nissan': [
    'Sentra', 'Altima', 'Versa', 'Rogue', 'Murano', 'Pathfinder', 'Frontier',
    'Titan', 'Kicks', 'Maxima', 'Armada', 'NV200',
  ],
  'Honda': [
    'Civic', 'Accord', 'CR-V', 'Pilot', 'HR-V', 'Odyssey', 'Ridgeline',
    'Fit', 'Passport', 'Insight',
  ],
  'Ford': [
    'F-150', 'F-250', 'F-350', 'Escape', 'Explorer', 'Edge', 'Expedition',
    'Ranger', 'Transit', 'Transit Connect', 'Bronco', 'Maverick', 'Mustang',
    'Fusion', 'Focus',
  ],
  'Chevrolet': [
    'Silverado 1500', 'Silverado 2500', 'Equinox', 'Traverse', 'Tahoe',
    'Suburban', 'Malibu', 'Cruze', 'Colorado', 'Blazer', 'Trax', 'Express',
    'Impala',
  ],
  'Jeep': [
    'Wrangler', 'Grand Cherokee', 'Cherokee', 'Compass', 'Renegade',
    'Gladiator', 'Wagoneer',
  ],
  'Hyundai': [
    'Elantra', 'Sonata', 'Tucson', 'Santa Fe', 'Kona', 'Palisade', 'Accent',
    'Venue', 'Ioniq',
  ],
  'Kia': [
    'Forte', 'Optima', 'K5', 'Sportage', 'Sorento', 'Soul', 'Telluride',
    'Rio', 'Seltos', 'Carnival',
  ],
  'RAM': ['1500', '2500', '3500', 'ProMaster', 'ProMaster City'],
  'GMC': [
    'Sierra 1500', 'Sierra 2500', 'Terrain', 'Acadia', 'Yukon', 'Canyon',
    'Savana',
  ],
  'Dodge': ['Charger', 'Challenger', 'Durango', 'Journey', 'Grand Caravan'],
  'Chrysler': ['Pacifica', '300', 'Voyager', 'Town & Country'],
  'Volkswagen': [
    'Jetta', 'Passat', 'Golf', 'Tiguan', 'Atlas', 'Taos', 'Beetle',
  ],
  'BMW': [
    'Serie 3', 'Serie 5', 'Serie 7', 'X1', 'X3', 'X5', 'X7', 'Serie 2',
  ],
  'Mercedes-Benz': [
    'Clase C', 'Clase E', 'Clase S', 'GLA', 'GLB', 'GLC', 'GLE', 'GLS',
    'Sprinter', 'Metris',
  ],
  'Audi': ['A3', 'A4', 'A6', 'Q3', 'Q5', 'Q7', 'Q8'],
  'Subaru': [
    'Outback', 'Forester', 'Crosstrek', 'Impreza', 'Legacy', 'Ascent', 'WRX',
  ],
  'Mazda': ['Mazda3', 'Mazda6', 'CX-3', 'CX-30', 'CX-5', 'CX-9', 'MX-5'],
  'Lexus': ['ES', 'IS', 'RX', 'NX', 'GX', 'LX', 'UX'],
  'Acura': ['ILX', 'TLX', 'RDX', 'MDX', 'Integra'],
  'Infiniti': ['Q50', 'Q60', 'QX50', 'QX60', 'QX80'],
  'Buick': ['Encore', 'Enclave', 'Envision', 'Regal'],
  'Cadillac': ['Escalade', 'XT4', 'XT5', 'XT6', 'CT4', 'CT5'],
  'Lincoln': ['Navigator', 'Aviator', 'Corsair', 'Nautilus'],
  'Volvo': ['XC40', 'XC60', 'XC90', 'S60', 'S90'],
  'Mitsubishi': ['Outlander', 'Eclipse Cross', 'Mirage', 'Lancer'],
  'Tesla': ['Model 3', 'Model Y', 'Model S', 'Model X', 'Cybertruck'],
  'Mini': ['Cooper', 'Countryman', 'Clubman'],
  'Fiat': ['500', '500X', '500L'],
  'Land Rover': [
    'Range Rover', 'Range Rover Sport', 'Discovery', 'Defender', 'Evoque',
  ],
  'Jaguar': ['F-Pace', 'E-Pace', 'XF', 'XE'],
  'Porsche': ['Macan', 'Cayenne', '911', 'Panamera', 'Taycan'],
  'Genesis': ['G70', 'G80', 'G90', 'GV70', 'GV80'],
  'Alfa Romeo': ['Giulia', 'Stelvio', 'Tonale'],
  // Pesados y comerciales: aquí el "modelo" suele ser la serie.
  'Freightliner': ['Cascadia', 'M2 106', 'Sprinter', 'Columbia', 'Coronado'],
  'International': ['LT', 'LoneStar', 'MV', 'HV', 'ProStar', 'DuraStar'],
  'Isuzu': ['NPR', 'NQR', 'NRR', 'FTR', 'D-Max'],
  'Peterbilt': ['379', '386', '389', '567', '579', '389 Glider'],
  'Kenworth': ['T680', 'T880', 'W900', 'T370', 'T800'],
};

/// Modelos de [make], o lista vacía si esa marca no tiene catálogo (incluida
/// la marca libre). Una lista vacía es la señal de "pide el modelo por texto".
List<String> vehicleModelsFor(String? make) {
  if (make == null) return const [];
  return kVehicleModelsByMake[make] ?? const [];
}
