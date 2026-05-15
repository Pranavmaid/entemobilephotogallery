import 'package:flutter_test/flutter_test.dart';

import 'package:entemobilephotogallery/main.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const EnteGalleryApp());
    await tester.pump();
  });
}
