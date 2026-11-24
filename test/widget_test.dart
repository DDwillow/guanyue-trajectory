import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guanyue_trajectory/main.dart';

void main() {
  testWidgets('App launches and shows title', (WidgetTester tester) async {
    await tester.pumpWidget(const GuanyueApp());
    await tester.pump();

    expect(find.text('观阅轨迹'), findsOneWidget);
  });
}
