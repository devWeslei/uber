import 'package:flutter/material.dart';
import 'package:uber/telas/Home.dart';

import 'Rotas.dart';

final ThemeData temaPadrao = ThemeData(
  colorScheme: ColorScheme.fromSwatch().copyWith(
    primary: const Color(0xff37474f),
    secondary: const Color(0xff546e7a),
  ),
);

void main() {
  runApp(MaterialApp(
    title: "Uber",
    home: Home(),
    theme:  temaPadrao,
    initialRoute: "/",
    onGenerateRoute: Rotas.gerarRotas,
    debugShowCheckedModeBanner: false,
  ));
}

