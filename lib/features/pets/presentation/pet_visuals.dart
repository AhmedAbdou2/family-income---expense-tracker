import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../domain/entities.dart';

String petTypeLabel(BuildContext context, PetType type) {
  final l10n = context.l10n;
  return switch (type) {
    PetType.cat => l10n.pet_type_cat,
    PetType.dog => l10n.pet_type_dog,
    PetType.bird => l10n.pet_type_bird,
    PetType.fish => l10n.pet_type_fish,
    PetType.other => l10n.pet_type_other,
  };
}

IconData petTypeIcon(PetType type) => switch (type) {
      PetType.cat => Icons.pets_rounded,
      PetType.dog => Icons.pets_rounded,
      PetType.bird => Icons.flutter_dash_rounded,
      PetType.fish => Icons.set_meal_rounded,
      PetType.other => Icons.pets_outlined,
    };
