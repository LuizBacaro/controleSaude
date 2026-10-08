/// Query string, não path: o GoRouter decodifica o path de novo e
/// estoura em nomes com acento ("não HDL", "Ácido úrico", "Triglicerídeos").
String markerRoute(String name) {
  return Uri(path: '/marcador', queryParameters: {'nome': name}).toString();
}
