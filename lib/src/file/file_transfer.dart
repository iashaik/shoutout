import 'dart:io';

/// Represents a file transfer (upload or download)
class FileTransfer {
  final String id;
  final String fileName;
  final int totalBytes;
  int transferredBytes;
  final FileTransferType type;
  FileTransferStatus status;
  final DateTime startedAt;
  DateTime? completedAt;
  String? error;
  String? resultUrl;

  FileTransfer({
    required this.id,
    required this.fileName,
    required this.totalBytes,
    this.transferredBytes = 0,
    required this.type,
    this.status = FileTransferStatus.pending,
    required this.startedAt,
    this.completedAt,
    this.error,
    this.resultUrl,
  });

  double get progress => totalBytes > 0 ? transferredBytes / totalBytes : 0.0;

  bool get isComplete => status == FileTransferStatus.completed;
  bool get isFailed => status == FileTransferStatus.failed;
  bool get isPaused => status == FileTransferStatus.paused;
  bool get isActive =>
      status == FileTransferStatus.uploading ||
      status == FileTransferStatus.downloading;

  FileTransfer copyWith({
    int? transferredBytes,
    FileTransferStatus? status,
    DateTime? completedAt,
    String? error,
    String? resultUrl,
  }) {
    return FileTransfer(
      id: id,
      fileName: fileName,
      totalBytes: totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      type: type,
      status: status ?? this.status,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      error: error ?? this.error,
      resultUrl: resultUrl ?? this.resultUrl,
    );
  }

  @override
  String toString() {
    return 'FileTransfer(id: $id, fileName: $fileName, progress: ${(progress * 100).toStringAsFixed(1)}%, status: $status)';
  }
}

enum FileTransferType { upload, download }

enum FileTransferStatus {
  pending,
  uploading,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Progress callback for file transfers
typedef FileProgressCallback = void Function(int sent, int total);

/// File transfer result
class FileTransferResult {
  final String transferId;
  final String fileName;
  final String? url;
  final File? file;
  final int bytes;
  final Duration duration;

  FileTransferResult({
    required this.transferId,
    required this.fileName,
    this.url,
    this.file,
    required this.bytes,
    required this.duration,
  });
}
