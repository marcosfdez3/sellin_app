import 'package:flutter/material.dart';

/// Estilo de los campos de las pantallas de acceso (login, recuperar contraseña).
InputDecoration authInputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFF16213E),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}
