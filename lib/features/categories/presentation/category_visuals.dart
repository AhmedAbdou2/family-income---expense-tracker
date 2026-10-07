import 'package:flutter/material.dart';

/// Icon vocabulary for categories: DB stores the plain Material icon
/// name, these maps resolve it for the UI. Unknown names fall back to
/// `category` so data from older/foreign builds still renders.
const Map<String, IconData> kCategoryIcons = {
  'category': Icons.category_rounded,
  'restaurant': Icons.restaurant_rounded,
  'shopping_basket': Icons.shopping_basket_rounded,
  'shopping_cart': Icons.shopping_cart_rounded,
  'bolt': Icons.bolt_rounded,
  'water_drop': Icons.water_drop_rounded,
  'local_fire_department': Icons.local_fire_department_rounded,
  'wifi': Icons.wifi_rounded,
  'phone_iphone': Icons.phone_iphone_rounded,
  'health_and_safety': Icons.health_and_safety_rounded,
  'school': Icons.school_rounded,
  'movie': Icons.movie_rounded,
  'checkroom': Icons.checkroom_rounded,
  'gift': Icons.card_giftcard_rounded,
  'more_horiz': Icons.more_horiz_rounded,
  'local_gas_station': Icons.local_gas_station_rounded,
  'build': Icons.build_rounded,
  'oil_barrel': Icons.oil_barrel_rounded,
  'shield': Icons.shield_rounded,
  'card_membership': Icons.card_membership_rounded,
  'local_car_wash': Icons.local_car_wash_rounded,
  'gavel': Icons.gavel_rounded,
  'payments': Icons.payments_rounded,
  'home': Icons.home_rounded,
  'credit_card': Icons.credit_card_rounded,
  'subscriptions': Icons.subscriptions_rounded,
  'savings': Icons.savings_rounded,
  'receipt_long': Icons.receipt_long_rounded,
  'add_circle': Icons.add_circle_rounded,
  'pets': Icons.pets_rounded,
  'fitness_center': Icons.fitness_center_rounded,
  'flight': Icons.flight_rounded,
};

IconData iconFor(String name) => kCategoryIcons[name] ?? Icons.category_rounded;

/// Preset palette (all values satisfy the `^#[0-9A-Fa-f]{6}$` check).
const List<String> kCategoryColors = [
  '#EF5350',
  '#FF7043',
  '#FFA726',
  '#FDD835',
  '#66BB6A',
  '#26C6DA',
  '#42A5F5',
  '#5C6BC0',
  '#7E57C2',
  '#AB47BC',
  '#EC407A',
  '#78909C',
];

Color colorFromHex(String hex) =>
    Color(int.parse('FF${hex.substring(1)}', radix: 16));
