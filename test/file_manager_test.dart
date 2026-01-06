import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoutout/shoutout.dart';

void main() {
  group('FileTransfer', () {
    test('calculates progress correctly', () {
      final transfer = FileTransfer(
        id: 'test-1',
        fileName: 'test.jpg',
        totalBytes: 1000,
        transferredBytes: 500,
        type: FileTransferType.upload,
        startedAt: DateTime.now(),
      );

      expect(transfer.progress, 0.5);
    });

    test('isComplete returns true when status is completed', () {
      final transfer = FileTransfer(
        id: 'test-1',
        fileName: 'test.jpg',
        totalBytes: 1000,
        type: FileTransferType.upload,
        status: FileTransferStatus.completed,
        startedAt: DateTime.now(),
      );

      expect(transfer.isComplete, true);
    });

    test('isActive returns true for uploading and downloading', () {
      final uploading = FileTransfer(
        id: 'test-1',
        fileName: 'test.jpg',
        totalBytes: 1000,
        type: FileTransferType.upload,
        status: FileTransferStatus.uploading,
        startedAt: DateTime.now(),
      );

      final downloading = FileTransfer(
        id: 'test-2',
        fileName: 'test.jpg',
        totalBytes: 1000,
        type: FileTransferType.download,
        status: FileTransferStatus.downloading,
        startedAt: DateTime.now(),
      );

      expect(uploading.isActive, true);
      expect(downloading.isActive, true);
    });

    test('copyWith creates new instance with updated values', () {
      final original = FileTransfer(
        id: 'test-1',
        fileName: 'test.jpg',
        totalBytes: 1000,
        transferredBytes: 0,
        type: FileTransferType.upload,
        startedAt: DateTime.now(),
      );

      final updated = original.copyWith(
        transferredBytes: 500,
        status: FileTransferStatus.uploading,
      );

      expect(updated.transferredBytes, 500);
      expect(updated.status, FileTransferStatus.uploading);
      expect(updated.id, original.id);
      expect(updated.fileName, original.fileName);
    });
  });

  group('FileTransferResult', () {
    test('creates result with all properties', () {
      final result = FileTransferResult(
        transferId: 'test-1',
        fileName: 'test.jpg',
        url: 'https://example.com/test.jpg',
        bytes: 1000,
        duration: Duration(seconds: 5),
      );

      expect(result.transferId, 'test-1');
      expect(result.fileName, 'test.jpg');
      expect(result.url, 'https://example.com/test.jpg');
      expect(result.bytes, 1000);
      expect(result.duration.inSeconds, 5);
    });
  });

  group('FileManager', () {
    late Dio dio;
    late FileManager fileManager;

    setUp(() {
      dio = Dio();
      fileManager = FileManager(dio: dio);
    });

    test('getTransfer returns null for non-existent transfer', () {
      expect(fileManager.getTransfer('non-existent'), null);
    });

    test('activeTransfers returns empty list initially', () {
      expect(fileManager.activeTransfers, isEmpty);
    });

    test('clearAll removes all transfers', () {
      fileManager.clearAll();
      expect(fileManager.activeTransfers, isEmpty);
    });
  });
}
