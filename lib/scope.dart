import 'package:flutter/widgets.dart';

import 'data/repository.dart';
import 'data/settings.dart';

/// 把仓储和设置挂到树上，页面里 `AppScope.of(context).repo` 就能拿到。
class AppScope extends InheritedWidget {
  final FitnessRepository repo;
  final Settings settings;

  const AppScope({
    super.key,
    required this.repo,
    required this.settings,
    required super.child,
  });

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope 没有挂在树上');
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant AppScope oldWidget) => false;
}
