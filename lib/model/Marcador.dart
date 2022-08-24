import 'package:google_maps_flutter/google_maps_flutter.dart';

class Marcador {

  final LatLng local;
  final String caminhoImagem;
  final String titulo;

  Marcador(this.local, this.caminhoImagem, this.titulo);
}