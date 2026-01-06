import 'package:flutter_test/flutter_test.dart';
import 'package:shoutout/shoutout.dart';

void main() {
  test('exports are accessible', () {
    // Verify main exports are available
    expect(ShoutoutClient, isNotNull);
    expect(ShoutoutConfig, isNotNull);
    expect(QueryBuilder, isNotNull);
    expect(FileManager, isNotNull);
    expect(BatchOperations, isNotNull);
    expect(MockShoutoutClient, isNotNull);
    expect(RealtimeClient, isNotNull);
  });

  test('Failure hierarchy is available', () {
    expect(NetworkFailure, isNotNull);
    expect(AuthenticationFailure, isNotNull);
    expect(NotFoundFailure, isNotNull);
  });

  test('Repository interfaces are available', () {
    expect(PaginatedResult, isNotNull);
  });
}
