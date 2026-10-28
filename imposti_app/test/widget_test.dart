import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:imposti_app/main.dart';
import 'package:imposti_app/providers/app_state.dart';

void main() {
  testWidgets('IMPOSTI Auth screen renders when logged out', (tester) async {
    final appState = AppState()..isInitializing = false;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: const ImpostiApp(),
      ),
    );
    await tester.pump();

    expect(find.text('IMPOSTI — სისტემაში შესვლა'), findsOneWidget);
    expect(find.text('შესვლა'), findsOneWidget);
  });
}
