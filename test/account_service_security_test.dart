import 'package:flutter_test/flutter_test.dart';
import 'package:prfitness/features/sync/data/account_service.dart';

void main() {
  test('default API endpoint is the production HTTPS endpoint', () {
    final Uri uri = Uri.parse(AccountService.defaultBaseUrl);

    expect(uri.scheme, 'https');
    expect(uri.host, 'prfitness.itltech.in');
    expect(uri.path, isEmpty);
  });

  test('remote cleartext HTTP authentication endpoint is rejected', () async {
    final AccountService service = AccountService();

    await expectLater(
      service.login(
        baseUrl: 'http://example.com',
        email: 'securitytest',
        password: '1234567890',
      ),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.message,
          'message',
          contains('HTTPS'),
        ),
      ),
    );
  });

  test('production base URL contains no embedded credentials or query', () {
    final Uri uri = Uri.parse(AccountService.defaultBaseUrl);

    expect(uri.userInfo, isEmpty);
    expect(uri.query, isEmpty);
    expect(uri.fragment, isEmpty);
  });
}
