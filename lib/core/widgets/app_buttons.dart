import 'package:flutter/material.dart';

/// Button styles for the two very different contexts in this app.
///
/// The global theme (`app_theme.dart`) sets
/// `minimumSize: Size.fromHeight(52)`, i.e. width = `double.infinity`, so a
/// button in a form Column/ListView stretches full width. The SAME
/// constraint explodes ("BoxConstraints forces an infinite width") the moment
/// a button is placed in an *unbounded-width* parent - a `Row`, `Wrap`,
/// `ListTile.trailing`, `AppBar.actions`, etc. Use [inline] there: it keeps
/// the 44px tap height but lets the button size to its content.
abstract final class AppButtons {
  static const ButtonStyle inline = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, 44)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: WidgetStatePropertyAll(
      EdgeInsetsDirectional.symmetric(horizontal: 16),
    ),
  );
}
