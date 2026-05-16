import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tpe_qr_saas/app.dart';

void main() {
  testWidgets('App démarre', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: TpeQrSaasApp(initialOnboardingSeen: false),
      ),
    );
    await tester.pump();
    expect(find.text('TPE QR SaaS'), findsOneWidget);
  });
}
