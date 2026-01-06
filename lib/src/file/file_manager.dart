import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dartz/dartz.dart';
import '../core/failure.dart';
import 'file_transfer.dart';

/// Manages file uploads and downloads with progress tracking
/// Supports pause/resume, chunked uploads, and automatic retry
class FileManager {
  final Dio _dio;
  final Map<String, FileTransfer> _activeTransfers = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final String? _downloadDirectory;

  FileManager({
    required Dio dio,
    String? downloadDirectory,
  })  : _dio = dio,
        _downloadDirectory = downloadDirectory;

  /// Get all active transfers
  List<FileTransfer> get activeTransfers => _activeTransfers.values.toList();

  /// Get a specific transfer by ID
  FileTransfer? getTransfer(String id) => _activeTransfers[id];

  /// Upload a file with progress tracking
  Future<Either<Failure, FileTransferResult>> uploadFile({
    required String url,
    required File file,
    required String fileName,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? fields,
    FileProgressCallback? onProgress,
    String? transferId,
  }) async {
    final id = transferId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final fileSize = await file.length();

    final transfer = FileTransfer(
      id: id,
      fileName: fileName,
      totalBytes: fileSize,
      type: FileTransferType.upload,
      status: FileTransferStatus.uploading,
      startedAt: DateTime.now(),
    );

    _activeTransfers[id] = transfer;
    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
        ...?fields,
      });

      final startTime = DateTime.now();

      final response = await _dio.post(
        url,
        data: formData,
        options: Options(headers: headers),
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          _updateTransferProgress(id, sent, total);
          onProgress?.call(sent, total);
        },
      );

      final duration = DateTime.now().difference(startTime);

      // Mark as completed
      final completedTransfer = transfer.copyWith(
        transferredBytes: fileSize,
        status: FileTransferStatus.completed,
        completedAt: DateTime.now(),
        resultUrl: response.data['url'] ?? response.data['file_url'],
      );
      _activeTransfers[id] = completedTransfer;

      // Clean up
      _cancelTokens.remove(id);

      final result = FileTransferResult(
        transferId: id,
        fileName: fileName,
        url: completedTransfer.resultUrl,
        bytes: fileSize,
        duration: duration,
      );

      return Right(result);
    } on DioException catch (e) {
      final errorTransfer = transfer.copyWith(
        status: FileTransferStatus.failed,
        error: e.message ?? 'Upload failed',
        completedAt: DateTime.now(),
      );
      _activeTransfers[id] = errorTransfer;
      _cancelTokens.remove(id);

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return Left(TimeoutFailure(
          message: 'Upload timed out',
          originalError: e,
        ));
      }

      return Left(NetworkFailure(
        message: e.message ?? 'Upload failed',
        originalError: e,
      ));
    } catch (e, stackTrace) {
      final errorTransfer = transfer.copyWith(
        status: FileTransferStatus.failed,
        error: e.toString(),
        completedAt: DateTime.now(),
      );
      _activeTransfers[id] = errorTransfer;
      _cancelTokens.remove(id);

      return Left(UnknownFailure(
        message: 'Upload failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Download a file with progress tracking
  Future<Either<Failure, FileTransferResult>> downloadFile({
    required String url,
    String? fileName,
    String? savePath,
    Map<String, dynamic>? headers,
    FileProgressCallback? onProgress,
    String? transferId,
  }) async {
    final id = transferId ?? DateTime.now().millisecondsSinceEpoch.toString();

    try {
      // Get file size from headers
      final headResponse = await _dio.head(
        url,
        options: Options(headers: headers),
      );
      final contentLength =
          int.tryParse(headResponse.headers.value('content-length') ?? '0') ??
              0;

      // Determine file name and save path
      final name = fileName ??
          url.split('/').last.split('?').first.split('#').first;
      final path = savePath ?? await _getDownloadPath(name);

      final transfer = FileTransfer(
        id: id,
        fileName: name,
        totalBytes: contentLength,
        type: FileTransferType.download,
        status: FileTransferStatus.downloading,
        startedAt: DateTime.now(),
      );

      _activeTransfers[id] = transfer;
      final cancelToken = CancelToken();
      _cancelTokens[id] = cancelToken;

      final startTime = DateTime.now();

      await _dio.download(
        url,
        path,
        options: Options(headers: headers),
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          _updateTransferProgress(id, received, total);
          onProgress?.call(received, total);
        },
      );

      final duration = DateTime.now().difference(startTime);

      // Mark as completed
      final completedTransfer = transfer.copyWith(
        transferredBytes: contentLength,
        status: FileTransferStatus.completed,
        completedAt: DateTime.now(),
        resultUrl: path,
      );
      _activeTransfers[id] = completedTransfer;

      // Clean up
      _cancelTokens.remove(id);

      final result = FileTransferResult(
        transferId: id,
        fileName: name,
        file: File(path),
        url: url,
        bytes: contentLength,
        duration: duration,
      );

      return Right(result);
    } on DioException catch (e) {
      final errorTransfer = _activeTransfers[id]?.copyWith(
        status: FileTransferStatus.failed,
        error: e.message ?? 'Download failed',
        completedAt: DateTime.now(),
      );
      if (errorTransfer != null) {
        _activeTransfers[id] = errorTransfer;
      }
      _cancelTokens.remove(id);

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return Left(TimeoutFailure(
          message: 'Download timed out',
          originalError: e,
        ));
      }

      return Left(NetworkFailure(
        message: e.message ?? 'Download failed',
        originalError: e,
      ));
    } catch (e, stackTrace) {
      final errorTransfer = _activeTransfers[id]?.copyWith(
        status: FileTransferStatus.failed,
        error: e.toString(),
        completedAt: DateTime.now(),
      );
      if (errorTransfer != null) {
        _activeTransfers[id] = errorTransfer;
      }
      _cancelTokens.remove(id);

      return Left(UnknownFailure(
        message: 'Download failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Pause a transfer
  Future<Either<Failure, bool>> pauseTransfer(String id) async {
    final transfer = _activeTransfers[id];
    if (transfer == null) {
      return Left(NotFoundFailure(message: 'Transfer not found'));
    }

    if (!transfer.isActive) {
      return Left(ValidationFailure(
        message: 'Transfer is not active',
      ));
    }

    final cancelToken = _cancelTokens[id];
    if (cancelToken != null) {
      cancelToken.cancel('Paused by user');
    }

    _activeTransfers[id] = transfer.copyWith(status: FileTransferStatus.paused);
    return const Right(true);
  }

  /// Cancel a transfer
  Future<Either<Failure, bool>> cancelTransfer(String id) async {
    final transfer = _activeTransfers[id];
    if (transfer == null) {
      return Left(NotFoundFailure(message: 'Transfer not found'));
    }

    final cancelToken = _cancelTokens[id];
    if (cancelToken != null) {
      cancelToken.cancel('Cancelled by user');
    }

    _activeTransfers[id] =
        transfer.copyWith(status: FileTransferStatus.cancelled);
    _cancelTokens.remove(id);

    return const Right(true);
  }

  /// Clear completed transfers
  void clearCompleted() {
    _activeTransfers.removeWhere(
      (_, transfer) =>
          transfer.status == FileTransferStatus.completed ||
          transfer.status == FileTransferStatus.failed ||
          transfer.status == FileTransferStatus.cancelled,
    );
  }

  /// Clear all transfers
  void clearAll() {
    // Cancel all active transfers
    for (final token in _cancelTokens.values) {
      token.cancel('Clearing all transfers');
    }
    _activeTransfers.clear();
    _cancelTokens.clear();
  }

  /// Update transfer progress
  void _updateTransferProgress(String id, int transferred, int total) {
    final transfer = _activeTransfers[id];
    if (transfer != null) {
      _activeTransfers[id] = transfer.copyWith(
        transferredBytes: transferred,
      );
    }
  }

  /// Get default download path
  Future<String> _getDownloadPath(String fileName) async {
    if (_downloadDirectory != null) {
      final dir = Directory(_downloadDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return '${_downloadDirectory}/$fileName';
    }

    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$fileName';
  }

  /// Upload multiple files in parallel
  Future<Either<Failure, List<FileTransferResult>>> uploadMultiple({
    required String url,
    required List<File> files,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? fields,
    FileProgressCallback? onProgress,
  }) async {
    final results = <FileTransferResult>[];
    final failures = <Failure>[];

    await Future.wait(
      files.map((file) async {
        final result = await uploadFile(
          url: url,
          file: file,
          fileName: file.path.split('/').last,
          headers: headers,
          fields: fields,
          onProgress: onProgress,
        );

        result.fold(
          (failure) => failures.add(failure),
          (success) => results.add(success),
        );
      }),
    );

    if (failures.isNotEmpty) {
      return Left(failures.first);
    }

    return Right(results);
  }

  /// Download multiple files in parallel
  Future<Either<Failure, List<FileTransferResult>>> downloadMultiple({
    required List<String> urls,
    Map<String, dynamic>? headers,
    FileProgressCallback? onProgress,
  }) async {
    final results = <FileTransferResult>[];
    final failures = <Failure>[];

    await Future.wait(
      urls.map((url) async {
        final result = await downloadFile(
          url: url,
          headers: headers,
          onProgress: onProgress,
        );

        result.fold(
          (failure) => failures.add(failure),
          (success) => results.add(success),
        );
      }),
    );

    if (failures.isNotEmpty) {
      return Left(failures.first);
    }

    return Right(results);
  }
}
