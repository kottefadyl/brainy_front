import 'dart:convert';

import 'package:flutter/material.dart';

import 'collections_api.dart';

Widget entryObjectRefField({
  required BuildContext context,
  required BrainyField field,
  required TextEditingController controller,
  required Map<String, String> objectNames,
  required bool isFrench,
  required VoidCallback onChoose,
  required Color ink,
}) {
  List<String> selected;
  try {
    selected = (jsonDecode(controller.text) as List<dynamic>).cast<String>();
  } catch (_) {
    selected = [];
  }
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.name,
          style: TextStyle(fontWeight: FontWeight.w700, color: ink),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onChoose,
          icon: const Icon(Icons.category_outlined),
          label: Text(isFrench ? 'Choisir des objets' : 'Choose objects'),
        ),
        if (selected.isNotEmpty)
          Text(selected.map((id) => objectNames[id] ?? id).join(', ')),
      ],
    ),
  );
}
