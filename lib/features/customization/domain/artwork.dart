import 'package:cloud_firestore/cloud_firestore.dart';

/// A digitized embroidery machine file (DST, EMB, PES...) attached by staff.
class DigitizedFile {
  const DigitizedFile({
    required this.name,
    required this.format,
    required this.url,
    required this.storagePath,
  });

  final String name;
  final String format;
  final String url;
  final String storagePath;

  factory DigitizedFile.fromMap(Map<String, dynamic> d) => DigitizedFile(
    name: d['name'] as String? ?? '',
    format: d['format'] as String? ?? '',
    url: d['url'] as String? ?? '',
    storagePath: d['storagePath'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'format': format,
    'url': url,
    'storagePath': storagePath,
  };
}

/// Artworks/{id} — a customer's saved logo. Uploaded once, reused on any
/// order. Staff attach the digitized file and stitch count, which waives
/// the digitizing fee and switches embroidery to stitch-based pricing.
class Artwork {
  const Artwork({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.fileUrl,
    required this.storagePath,
    required this.contentType,
    required this.sizeBytes,
    required this.digitized,
    required this.stitchCount,
    required this.threadCount,
    required this.digitizedFiles,
    required this.staffNotes,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String fileUrl;
  final String storagePath;
  final String contentType;
  final int sizeBytes;
  final bool digitized;
  final int? stitchCount;
  final int? threadCount;
  final List<DigitizedFile> digitizedFiles;
  final String staffNotes;
  final DateTime createdAt;

  /// Only raster images can be drawn on the mockup; vector/PDF files are
  /// shown as a labelled box instead.
  bool get isPreviewable =>
      contentType == 'image/png' ||
      contentType == 'image/jpeg' ||
      contentType == 'image/webp' ||
      contentType == 'image/gif';

  factory Artwork.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Artwork(
      id: doc.id,
      ownerId: d['ownerId'] as String? ?? '',
      name: d['name'] as String? ?? '',
      fileUrl: d['fileUrl'] as String? ?? '',
      storagePath: d['storagePath'] as String? ?? '',
      contentType: d['contentType'] as String? ?? '',
      sizeBytes: (d['sizeBytes'] as num?)?.toInt() ?? 0,
      digitized: d['digitized'] as bool? ?? false,
      stitchCount: (d['stitchCount'] as num?)?.toInt(),
      threadCount: (d['threadCount'] as num?)?.toInt(),
      digitizedFiles: [
        for (final f in (d['digitizedFiles'] as List? ?? const []))
          DigitizedFile.fromMap(Map<String, dynamic>.from(f as Map)),
      ],
      staffNotes: d['staffNotes'] as String? ?? '',
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
