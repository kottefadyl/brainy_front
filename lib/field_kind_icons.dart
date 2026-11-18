import 'package:flutter/material.dart';

import 'collections_api.dart';

/// One icon per field type (same meaning as the web's field-kind-icons.tsx), beside fields in the entry form.
IconData fieldKindIcon(BrainyFieldKind kind) => switch (kind) {
      BrainyFieldKind.title => Icons.title_rounded,
      BrainyFieldKind.text => Icons.short_text_rounded,
      BrainyFieldKind.longText => Icons.notes_rounded,
      BrainyFieldKind.number => Icons.tag_rounded,
      BrainyFieldKind.date => Icons.calendar_today_outlined,
      BrainyFieldKind.time => Icons.schedule_rounded,
      BrainyFieldKind.datetime => Icons.event_outlined,
      BrainyFieldKind.duration => Icons.timer_outlined,
      BrainyFieldKind.link => Icons.link_rounded,
      BrainyFieldKind.character => Icons.text_fields_rounded,
      BrainyFieldKind.boolean => Icons.check_box_outlined,
      BrainyFieldKind.select => Icons.radio_button_checked_rounded,
      BrainyFieldKind.multiSelect => Icons.checklist_rounded,
      BrainyFieldKind.attachment => Icons.attach_file_rounded,
      BrainyFieldKind.objectRef => Icons.inventory_2_outlined,
      BrainyFieldKind.collaborator => Icons.group_outlined,
      BrainyFieldKind.measure => Icons.straighten_rounded,
      BrainyFieldKind.position => Icons.place_outlined,
      BrainyFieldKind.zone => Icons.map_outlined,
      BrainyFieldKind.code => Icons.sell_outlined,
    };
