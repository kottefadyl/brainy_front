/// Names of the analysis operations in English and French, as on the web (`lib/analysis-operations.ts`).
const analysisOperationNames = <String, (String, String)>{
  'COUNT': ('Count', 'Nombre'),
  'SUM': ('Sum', 'Somme'),
  'AVERAGE': ('Average', 'Moyenne'),
  'MIN': ('Min', 'Minimum'),
  'MAX': ('Max', 'Maximum'),
  'MEDIAN': ('Median', 'Médiane'),
  'PERCENTILE': ('Percentile', 'Centile'),
  'PERCENTILE_25': ('25th percentile (P25)', 'Quantile P25'),
  'PERCENTILE_75': ('75th percentile (P75)', 'Quantile P75'),
  'PERCENTILE_95': ('95th percentile (P95)', 'Quantile P95'),
  'MODE': ('Mode (most frequent value)', 'Mode (valeur la plus fréquente)'),
  'VARIANCE': ('Variance', 'Variance'),
  'STDDEV': ('Standard deviation', 'Écart-type'),
  'STDDEV_SAMPLE': ('Standard deviation (sample)', 'Écart-type (échantillon)'),
  'RANGE': ('Range (Max − Min)', 'Étendue (Max − Min)'),
  'RATE_PER_N': ('Rate per N', 'Taux pour N'),
  'CROSSTAB': ('Cross-tabulation (2D)', 'Tableau croisé (2D)'),
  'CUMULATIVE': ('Cumulative sum', 'Cumul'),
  'MOVING_AVERAGE': ('Moving average', 'Moyenne mobile'),
  'SUCCESSIVE_DIFF': ('Successive difference (meter)', 'Écart successif (compteur)'),
  'SUCCESSIVE_VARIATION': ('Successive variation (%)', 'Variation successive (%)'),
  'LINEAR_TREND': ('Linear trend', 'Tendance linéaire'),
};

/// A code the client does not know stays readable rather than hidden.
String analysisOperationLabel(String id, {required bool french}) {
  final known = analysisOperationNames[id];
  if (known == null) return id.toLowerCase().replaceAll('_', ' ');
  return french ? known.$2 : known.$1;
}
