/// Garantiza que la consulta dependiente solo se ejecute después de que la
/// persistencia del avance termine correctamente.
Future<void> guardarAntesDeConsultar({
  required Future<void> Function() guardar,
  required Future<void> Function() consultar,
}) async {
  await guardar();
  await consultar();
}
