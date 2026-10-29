/// Vista determinista del texto almacenado. No resume mediante IA ni modifica
/// el diagnóstico original; el límite visual se complementa con maxLines.
class DiagnosticoPresentacion {
  static const int maxCaracteres = 240;

  static bool necesitaExpandir(String diagnostico) =>
      diagnostico.trim().length > maxCaracteres;

  static String textoVisible(String diagnostico, {required bool expandido}) {
    final original = diagnostico.trim();
    if (expandido || original.length <= maxCaracteres) return original;
    final corte = original.lastIndexOf(' ', maxCaracteres);
    final indice = corte > 0 ? corte : maxCaracteres;
    return '${original.substring(0, indice).trimRight()}…';
  }
}
