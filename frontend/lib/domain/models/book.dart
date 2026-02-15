/// Domain models for the book reader.

class BookData {
  final int id;
  final String title;
  final int totalPages;
  final int manifestVersion;
  final bool isPublished;

  BookData({
    required this.id,
    required this.title,
    required this.totalPages,
    required this.manifestVersion,
    required this.isPublished,
  });

  factory BookData.fromJson(Map<String, dynamic> json) => BookData(
    id: json['id'] ?? 0,
    title: json['title'] ?? '',
    totalPages: json['total_pages'] ?? 0,
    manifestVersion: json['manifest_version'] ?? 0,
    isPublished: json['is_published'] ?? false,
  );
}

class Chapter {
  final int id;
  final String title;
  final String? titleAr;
  final int sortOrder;
  final int? startPage;
  final int? endPage;

  Chapter({
    required this.id,
    required this.title,
    this.titleAr,
    required this.sortOrder,
    this.startPage,
    this.endPage,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
    id: json['id'] ?? 0,
    title: json['title'] ?? '',
    titleAr: json['title_ar'],
    sortOrder: json['sort_order'] ?? 0,
    startPage: json['start_page'],
    endPage: json['end_page'],
  );
}

class PageSummary {
  final int id;
  final int pageNumber;
  final String? imageUrl;
  final bool hasTextData;
  final bool isAnnotated;

  PageSummary({
    required this.id,
    required this.pageNumber,
    this.imageUrl,
    required this.hasTextData,
    required this.isAnnotated,
  });

  factory PageSummary.fromJson(Map<String, dynamic> json) => PageSummary(
    id: json['id'] ?? 0,
    pageNumber: json['page_number'] ?? 0,
    imageUrl: json['image_url'],
    hasTextData: json['has_text_data'] ?? false,
    isAnnotated: json['is_annotated'] ?? false,
  );
}

class PageDetail {
  final int id;
  final int pageNumber;
  final String layoutType; // "pdf" | "native"
  final String? imageUrl;
  final String? image2xUrl;
  final String? sourceImageUrl;
  final int? imageWidth;
  final int? imageHeight;
  final bool hasTextData;
  final bool isAnnotated;
  final String analysisStatus; // empty|pending|analyzing|draft|published|error
  final List<TextUnit> textUnits;
  final List<Section> sections;

  PageDetail({
    required this.id,
    required this.pageNumber,
    this.layoutType = 'pdf',
    this.imageUrl,
    this.image2xUrl,
    this.sourceImageUrl,
    this.imageWidth,
    this.imageHeight,
    required this.hasTextData,
    required this.isAnnotated,
    this.analysisStatus = 'empty',
    required this.textUnits,
    this.sections = const [],
  });

  /// True when page has an uploaded image and bbox-positioned units
  bool get hasOverlayData =>
      sourceImageUrl != null &&
      sourceImageUrl!.isNotEmpty &&
      textUnits.any((u) => u.bboxW > 0);

  factory PageDetail.fromJson(Map<String, dynamic> json) => PageDetail(
    id: json['id'] ?? 0,
    pageNumber: json['page_number'] ?? 0,
    layoutType: json['layout_type'] ?? 'pdf',
    imageUrl: json['image_url'],
    image2xUrl: json['image_2x_url'],
    sourceImageUrl: json['source_image_url'],
    imageWidth: json['image_width'],
    imageHeight: json['image_height'],
    hasTextData: json['has_text_data'] ?? false,
    isAnnotated: json['is_annotated'] ?? false,
    analysisStatus: json['analysis_status'] ?? 'empty',
    textUnits: (json['text_units'] as List?)
        ?.map((e) => TextUnit.fromJson(e))
        .toList() ?? [],
    sections: (json['sections'] as List?)
        ?.map((e) => Section.fromJson(e))
        .toList() ?? [],
  );
}

class TextUnit {
  final int id;
  final String unitType;
  final String textContent;
  final double bboxX;
  final double bboxY;
  final double bboxW;
  final double bboxH;
  final int sortOrder;
  final bool isManual;
  final double? confidence;
  final String? audioSegmentUrl;
  final Map<String, dynamic> metadata;

  TextUnit({
    required this.id,
    required this.unitType,
    required this.textContent,
    required this.bboxX,
    required this.bboxY,
    required this.bboxW,
    required this.bboxH,
    required this.sortOrder,
    required this.isManual,
    this.confidence,
    this.audioSegmentUrl,
    this.metadata = const {},
  });

  factory TextUnit.fromJson(Map<String, dynamic> json) => TextUnit(
    id: json['id'] ?? 0,
    unitType: json['unit_type'] ?? 'letter',
    textContent: json['text_content'] ?? '',
    bboxX: (json['bbox_x'] ?? 0).toDouble(),
    bboxY: (json['bbox_y'] ?? 0).toDouble(),
    bboxW: (json['bbox_w'] ?? 0).toDouble(),
    bboxH: (json['bbox_h'] ?? 0).toDouble(),
    sortOrder: json['sort_order'] ?? 0,
    isManual: json['is_manual'] ?? false,
    confidence: (json['confidence'] as num?)?.toDouble(),
    audioSegmentUrl: json['audio_segment_url'],
    metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
  );

  /// Get section from metadata
  String get section => (metadata['section'] as String?) ?? '';

  /// Get label from metadata
  String get label => (metadata['label'] as String?) ?? textContent;

  /// Get grid position from metadata
  Map<String, dynamic>? get grid => metadata['grid'] as Map<String, dynamic>?;

  /// Get render info from metadata
  Map<String, dynamic>? get renderInfo => metadata['render'] as Map<String, dynamic>?;
}


/// A section groups related text units into a pedagogical block.
class Section {
  final int id;
  final String sectionType;
  final String? targetLetter;
  final String? titleAr;
  final String? titleUz;
  final int sortOrder;
  final List<int> unitIds;
  final double? bboxYStart;
  final double? bboxYEnd;
  final bool isManual;

  Section({
    required this.id,
    required this.sectionType,
    this.targetLetter,
    this.titleAr,
    this.titleUz,
    required this.sortOrder,
    required this.unitIds,
    this.bboxYStart,
    this.bboxYEnd,
    this.isManual = false,
  });

  factory Section.fromJson(Map<String, dynamic> json) => Section(
    id: json['id'] ?? 0,
    sectionType: json['section_type'] ?? 'generic',
    targetLetter: json['target_letter'],
    titleAr: json['title_ar'],
    titleUz: json['title_uz'],
    sortOrder: json['sort_order'] ?? 0,
    unitIds: (json['unit_ids'] as List?)?.map((e) => e as int).toList() ?? [],
    bboxYStart: (json['bbox_y_start'] as num?)?.toDouble(),
    bboxYEnd: (json['bbox_y_end'] as num?)?.toDouble(),
    isManual: json['is_manual'] ?? false,
  );

  /// Display title — prefer Uzbek, fallback to Arabic
  String get displayTitle {
    if (titleUz != null && titleUz!.isNotEmpty) return titleUz!;
    if (titleAr != null && titleAr!.isNotEmpty) return titleAr!;
    return sectionType;
  }

  /// Short chip label for navigator
  String get chipLabel {
    if (targetLetter != null && targetLetter!.isNotEmpty) return targetLetter!;
    return displayTitle;
  }
}
