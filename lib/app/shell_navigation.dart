import 'package:flutter/widgets.dart';

class ShellNavigation extends InheritedWidget {
  const ShellNavigation({
    super.key,
    required this.goTo,
    required super.child,
  });

  final void Function(int index) goTo;

  static ShellNavigation of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<ShellNavigation>();
    assert(result != null, 'ShellNavigation is only available inside SottoShell');
    return result!;
  }

  @override
  bool updateShouldNotify(ShellNavigation oldWidget) => false;
}
