import 'package:flutter_test/flutter_test.dart';
import 'package:shoutout/shoutout.dart';

void main() {
  group('MockShoutoutClient', () {
    late MockShoutoutClient client;

    setUp(() {
      client = MockShoutoutClient(
        simulateNetworkDelay: false,
        randomFailures: false,
      );
    });

    tearDown(() {
      client.clear();
    });

    test('creates document and stores it', () async {
      final result = await client.createDocument(
        doctype: 'User',
        data: {'email': 'test@example.com'},
      );

      result.fold(
        (failure) => fail('Should not fail'),
        (doc) {
          expect(doc['email'], 'test@example.com');
          expect(doc['doctype'], 'User');
          expect(doc['name'], isNotNull);
        },
      );
    });

    test('retrieves created document by name', () async {
      final createResult = await client.createDocument(
        doctype: 'User',
        data: {'name': 'user1', 'email': 'test@example.com'},
      );

      late String docName;
      createResult.fold(
        (failure) => fail('Should not fail'),
        (doc) => docName = doc['name'],
      );

      final getResult = await client.getDocument(
        doctype: 'User',
        name: docName,
      );

      getResult.fold(
        (failure) => fail('Should not fail'),
        (doc) {
          expect(doc['name'], docName);
          expect(doc['email'], 'test@example.com');
        },
      );
    });

    test('returns NotFoundFailure for non-existent document', () async {
      final result = await client.getDocument(
        doctype: 'User',
        name: 'non-existent',
      );

      result.fold(
        (failure) {
          expect(failure, isA<NotFoundFailure>());
          expect(failure.message, contains('not found'));
        },
        (doc) => fail('Should return failure'),
      );
    });

    test('updates existing document', () async {
      final createResult = await client.createDocument(
        doctype: 'User',
        data: {'name': 'user1', 'email': 'old@example.com'},
      );

      late String docName;
      createResult.fold(
        (failure) => fail('Should not fail'),
        (doc) => docName = doc['name'],
      );

      final updateResult = await client.updateDocument(
        doctype: 'User',
        name: docName,
        data: {'email': 'new@example.com'},
      );

      updateResult.fold(
        (failure) => fail('Should not fail'),
        (doc) {
          expect(doc['email'], 'new@example.com');
          expect(doc['modified'], isNotNull);
        },
      );
    });

    test('deletes document', () async {
      final createResult = await client.createDocument(
        doctype: 'User',
        data: {'name': 'user1'},
      );

      late String docName;
      createResult.fold(
        (failure) => fail('Should not fail'),
        (doc) => docName = doc['name'],
      );

      final deleteResult = await client.deleteDocument(
        doctype: 'User',
        name: docName,
      );

      deleteResult.fold(
        (failure) => fail('Should not fail'),
        (success) => expect(success, true),
      );

      // Verify document is gone
      final getResult = await client.getDocument(
        doctype: 'User',
        name: docName,
      );

      getResult.fold(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (doc) => fail('Document should be deleted'),
      );
    });

    test('getDocuments returns filtered results', () async {
      await client.createDocument(
        doctype: 'User',
        data: {'name': 'user1', 'enabled': 1},
      );
      await client.createDocument(
        doctype: 'User',
        data: {'name': 'user2', 'enabled': 0},
      );
      await client.createDocument(
        doctype: 'User',
        data: {'name': 'user3', 'enabled': 1},
      );

      final result = await client.getDocuments(
        doctype: 'User',
        filters: {'enabled': 1},
      );

      result.fold(
        (failure) => fail('Should not fail'),
        (docs) => expect(docs.length, 2),
      );
    });

    test('getDocuments applies limit', () async {
      for (var i = 0; i < 10; i++) {
        await client.createDocument(
          doctype: 'User',
          data: {'name': 'user$i'},
        );
      }

      final result = await client.getDocuments(
        doctype: 'User',
        limit: 5,
      );

      result.fold(
        (failure) => fail('Should not fail'),
        (docs) => expect(docs.length, 5),
      );
    });

    test('getDocuments applies offset', () async {
      for (var i = 0; i < 10; i++) {
        await client.createDocument(
          doctype: 'User',
          data: {'name': 'user$i'},
        );
      }

      final result = await client.getDocuments(
        doctype: 'User',
        offset: 5,
        limit: 3,
      );

      result.fold(
        (failure) => fail('Should not fail'),
        (docs) => expect(docs.length, 3),
      );
    });

    test('seed populates data', () {
      client.seed('User', [
        {'name': 'user1', 'email': 'user1@example.com'},
        {'name': 'user2', 'email': 'user2@example.com'},
      ]);

      expect(client.getDocumentCount('User'), 2);
      expect(client.documentExists('User', 'user1'), true);
    });

    test('clear removes all data', () async {
      await client.createDocument(
        doctype: 'User',
        data: {'name': 'user1'},
      );

      client.clear();

      expect(client.getDocumentCount('User'), 0);
    });

    test('clearDoctype removes only specific doctype', () async {
      await client.createDocument(
        doctype: 'User',
        data: {'name': 'user1'},
      );
      await client.createDocument(
        doctype: 'Task',
        data: {'name': 'task1'},
      );

      client.clearDoctype('User');

      expect(client.getDocumentCount('User'), 0);
      expect(client.getDocumentCount('Task'), 1);
    });

    test('tracks call count', () async {
      client.resetCallCount();

      await client.createDocument(
        doctype: 'User',
        data: {'name': 'user1'},
      );
      await client.getDocuments(doctype: 'User');

      expect(client.callCount, 2);
    });

    test('getAllDocuments returns all documents', () {
      client.seed('User', [
        {'name': 'user1'},
        {'name': 'user2'},
        {'name': 'user3'},
      ]);

      final docs = client.getAllDocuments('User');

      expect(docs.length, 3);
    });
  });

  group('MockClientBuilder', () {
    test('builds client with custom configuration', () {
      final client = MockClientBuilder()
          .withNetworkDelay(true, delay: Duration(milliseconds: 50))
          .withRandomFailures(true, rate: 0.2)
          .build();

      expect(client, isNotNull);
    });

    test('builds client with seed data', () {
      final client = MockClientBuilder()
          .withSeedData('User', [
        {'name': 'user1', 'email': 'user1@example.com'},
      ]).build();

      expect(client.getDocumentCount('User'), 1);
      expect(client.documentExists('User', 'user1'), true);
    });

    test('builds client with network delay disabled', () {
      final client = MockClientBuilder()
          .withNetworkDelay(false)
          .build();

      expect(client, isNotNull);
    });
  });
}
