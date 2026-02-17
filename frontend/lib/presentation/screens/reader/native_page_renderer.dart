import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/models/book.dart';
import '../../../core/l10n/app_localizations.dart';

/// Universal native interactive page renderer with premium Arabic font + animations.
///
/// Supports all section types via metadata:
///   - bismillah: Large centered title (green)
///   - title: Section title/heading
///   - alphabet: Letter grid with rows/cols
///   - harakat: Harakat letters in a row
///   - syllable_row: Row of syllables (words with harakat)
///   - word_row: Row of words
///   - divider: Ornamental *** divider
///   - default: Generic row of units
class NativePageRenderer extends StatefulWidget {
  final PageDetail page;
  final Function(TextUnit) onUnitTap;
  final int? activeUnitId;
  final Function(List<int>)? onSectionPlay;

  const NativePageRenderer({
    super.key,
    required this.page,
    required this.onUnitTap,
    this.activeUnitId,
    this.onSectionPlay,
  });

  @override
  State<NativePageRenderer> createState() => _NativePageRendererState();
}

class _NativePageRendererState extends State<NativePageRenderer> {
  final ScrollController _scrollController = ScrollController();
  int _activeSectionIndex = 0;
  final Map<int, GlobalKey> _sectionKeys = {};

  @override
  void initState() {
    super.initState();
    // Create keys for each API section
    for (int i = 0; i < widget.page.sections.length; i++) {
      _sectionKeys[i] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(int index) {
    final key = _sectionKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.0,
      );
      setState(() => _activeSectionIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final onUnitTap = widget.onUnitTap;
    final activeUnitId = widget.activeUnitId;

    // ── MODE SELECTION ──
    if (page.hasOverlayData &&
        (page.analysisStatus == 'PUBLISHED' ||
         page.analysisStatus == 'DRAFT')) {
      return ImageOverlayRenderer(
        page: page,
        onUnitTap: onUnitTap,
        activeUnitId: activeUnitId,
      );
    }

    // ── COVER PAGE (page 1) ──
    if (page.pageNumber == 1) {
      return _CoverPage(
        units: page.textUnits,
        activeUnitId: activeUnitId,
        onUnitTap: onUnitTap,
      );
    }

    // ── MUQADDIMA PAGE (page 2) ──
    if (page.pageNumber == 2) {
      return _MuqaddimaPage(
        units: page.textUnits,
        activeUnitId: activeUnitId,
        onUnitTap: onUnitTap,
        showHeader: page.pageNumber == 2,
      );
    }

    // ── SECTION-BASED RENDERING ──
    // Build metadata-based visual groups from ALL units
    final metaGroups = <String, List<TextUnit>>{};
    final metaOrder = <String>[];
    for (final u in page.textUnits) {
      final sec = u.section.isEmpty ? 'default_${u.sortOrder}' : u.section;
      if (!metaGroups.containsKey(sec)) {
        metaOrder.add(sec);
      }
      metaGroups.putIfAbsent(sec, () => []).add(u);
    }

    final hasApiSections = page.sections.isNotEmpty;

    // Build the visual section widgets
    List<Widget> contentChildren;

    if (hasApiSections) {
      // ── API-section driven layout ──
      // Each API section wraps 1+ metadata visual groups.
      // A unit's membership is determined by section.unitIds.
      final unitToApiSection = <int, int>{};
      for (int si = 0; si < page.sections.length; si++) {
        for (final uid in page.sections[si].unitIds) {
          unitToApiSection[uid] = si;
        }
      }

      // Group metadata groups under their API section
      final apiSectionMetaGroups = <int, List<MapEntry<String, List<TextUnit>>>>{};
      for (final metaKey in metaOrder) {
        final units = metaGroups[metaKey]!;
        // Determine which API section this metadata group belongs to
        // by checking the first unit
        final firstUnitId = units.first.id;
        final apiIdx = unitToApiSection[firstUnitId] ?? 0;
        apiSectionMetaGroups
            .putIfAbsent(apiIdx, () => [])
            .add(MapEntry(metaKey, units));
      }

      contentChildren = [];
      for (int si = 0; si < page.sections.length; si++) {
        final groups = apiSectionMetaGroups[si] ?? [];
        final sectionWidgets = <Widget>[];
        for (final entry in groups) {
          final sectionType = _getSectionType(entry.key, entry.value);
          // Insert ULTRA divider before title sections (new lesson)
          if (sectionType == 'title' && sectionWidgets.isNotEmpty) {
            sectionWidgets.add(const _LessonDivider());
          }
          sectionWidgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSection(sectionType, entry.key, entry.value),
            ),
          );
        }
        contentChildren.add(
          Container(
            key: _sectionKeys[si],
            child: Column(children: sectionWidgets),
          ),
        );
      }
    } else {
      // ── Fallback: pure metadata-based layout with smart lesson detection ──
      // When sections are empty, detect "harakat triplets" (3 consecutive
      // short units like مَ مِ مُ) as new lesson boundaries and insert dividers.
      
      // First, flatten all units for triplet detection
      final allUnits = <TextUnit>[];
      for (final secKey in metaOrder) {
        allUnits.addAll(metaGroups[secKey]!);
      }
      
      // Find harakat triplet start indices
      final tripletStarts = <int>{};
      for (int i = 0; i + 2 < allUnits.length; i++) {
        final u0 = allUnits[i].textContent.trim();
        final u1 = allUnits[i + 1].textContent.trim();
        final u2 = allUnits[i + 2].textContent.trim();
        // A harakat triplet: 3 consecutive units, each is a single
        // Arabic letter + harakat (runes length == 2, or char length <= 3)
        if (u0.runes.length <= 2 && u1.runes.length <= 2 && u2.runes.length <= 2 &&
            u0.isNotEmpty && u1.isNotEmpty && u2.isNotEmpty) {
          tripletStarts.add(i);
        }
      }
      
      // Build unit-to-flatIndex mapping
      final unitIdToFlatIndex = <int, int>{};
      for (int i = 0; i < allUnits.length; i++) {
        unitIdToFlatIndex[allUnits[i].id] = i;
      }
      
      contentChildren = [];
      for (int i = 0; i < metaOrder.length; i++) {
        final secKey = metaOrder[i];
        final units = metaGroups[secKey]!;
        final sectionType = _getSectionType(secKey, units);
        
        // Check if this group's first unit is a triplet start
        final firstUnitFlatIdx = unitIdToFlatIndex[units.first.id] ?? -1;
        final isNewLesson = tripletStarts.contains(firstUnitFlatIdx);
        
        // Insert ULTRA divider before new lesson (harakat triplet or title or ya_header)
        if ((isNewLesson || sectionType == 'title' || secKey.contains('ya_header')) && contentChildren.isNotEmpty) {
          contentChildren.add(const _LessonDivider());
        }
        
        // For triplet lesson starts, force large text rendering
        final Widget sectionWidget;
        if (isNewLesson && sectionType != 'title' && sectionType != 'bismillah') {
          sectionWidget = _UnitRow(
            units: units,
            activeUnitId: widget.activeUnitId,
            onUnitTap: widget.onUnitTap,
            isLargeText: true,
          );
        } else {
          sectionWidget = _buildSection(sectionType, secKey, units);
        }
        
        contentChildren.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: sectionWidget,
          ),
        );
      }
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFDF5),
            Color(0xFFF8F5EC),
          ],
        ),
      ),
      child: Column(
        children: [

          // ── Page content ──
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 400 ? 8 : 16,
                vertical: hasApiSections ? 12 : 24,
              ),
              child: Column(
                children: [
                  if (!hasApiSections) const SizedBox(height: 20),
                  ...contentChildren,
                  const SizedBox(height: 64),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSectionType(String sectionKey, List<TextUnit> units) {
    // Determine section type from key or unit metadata
    if (sectionKey.startsWith('bismillah')) return 'bismillah';
    if (sectionKey.startsWith('title')) return 'title';
    if (sectionKey.startsWith('alphabet')) return 'alphabet';
    if (sectionKey.startsWith('harakat')) return 'harakat';
    if (sectionKey.startsWith('syllable')) return 'syllable_row';
    if (sectionKey.startsWith('word')) return 'word_row';
    if (sectionKey.startsWith('divider')) return 'divider';
    // Check first unit's section metadata
    if (units.isNotEmpty) {
      final firstSection = units.first.section;
      // Madd intro note (special ultra UI)
      if (firstSection == 'madd_intro') return 'madd_intro';
      // Surah titles (e.g. surah_fatiha_title) — must check before generic 'title'
      if (firstSection.startsWith('surah_') && firstSection.endsWith('_title')) return 'surah_title';
      // Kalima/Iman titles
      if ((firstSection.startsWith('kalima_') || firstSection.startsWith('iman_')) && firstSection.endsWith('_title')) return 'title';
      // Notes
      if (firstSection.contains('_note')) return 'note';
      // Ayat sections (Quranic verses)
      if (firstSection.endsWith('_ayat') || firstSection.endsWith('_ayat_cont')) return 'ayat';
      // Dua/Kalima sections
      if (firstSection.startsWith('kalima_') || firstSection.startsWith('iman_') || firstSection == 'mashiatullah' || firstSection == 'istiaza' || firstSection == 'iman_tarif') return 'dua';
      // Explanations
      if (firstSection.endsWith('_explanation') || firstSection.endsWith('_footnote')) return 'explanation';
      // Harf grid (letter names with labels)
      if (firstSection.startsWith('harf_r')) return 'harf_grid';
      // Muqatta'at
      if (firstSection.startsWith('muqattaat_r')) return 'muqattaat';
      if (firstSection == 'muqattaat_note') return 'explanation';
      // Existing types
      if (firstSection.contains('maddi_title')) return 'title';
      if (firstSection.contains('maddi_headers')) return 'maddi_table';
      if (firstSection.contains('maddi_')) return 'maddi_table';
      // Lesson 5-7 pages (19-21) — headers are titles, rest are word rows
      if (firstSection.contains('_header')) return 'title';
      if (firstSection.startsWith('lesson5_')) return 'madd_word_row';
      if (firstSection.startsWith('lesson6_')) return 'madd_word_row';
      if (firstSection.startsWith('lesson7_')) return 'madd_word_row';
      if (firstSection.contains('bismillah')) return 'bismillah';
      if (firstSection.contains('title')) return 'title';
      if (firstSection.contains('alphabet')) return 'alphabet';
      if (firstSection.contains('harakat')) return 'harakat';
      if (firstSection.contains('syllable')) return 'syllable_row';
      if (firstSection.contains('word')) return 'word_row';
      if (firstSection.contains('divider')) return 'divider';
    }
    return 'generic_row';
  }

  Widget _buildSection(String type, String key, List<TextUnit> units) {
    final activeUnitId = widget.activeUnitId;
    final onUnitTap = widget.onUnitTap;
    switch (type) {
      case 'bismillah':
        return _BismillahUnit(
          unit: units.first,
          isActive: activeUnitId == units.first.id,
          onTap: () => onUnitTap(units.first),
        );

      case 'title':
        return _TitleUnit(
          unit: units.first,
          isActive: activeUnitId == units.first.id,
          onTap: () => onUnitTap(units.first),
        );

      case 'surah_title':
        return _SurahTitle(
          unit: units.first,
          isActive: activeUnitId == units.first.id,
          onTap: () => onUnitTap(units.first),
        );

      case 'madd_intro':
        return _MaddIntroNote(
          units: units,
          activeUnitId: activeUnitId,
          onUnitTap: onUnitTap,
        );

      case 'ayat':
        return _AyatSection(
          units: units,
          activeUnitId: activeUnitId,
          onUnitTap: onUnitTap,
        );

      case 'dua':
        return _DuaSection(
          units: units,
          activeUnitId: activeUnitId,
          onUnitTap: onUnitTap,
        );

      case 'explanation':
        return _ExplanationUnit(
          units: units,
          activeUnitId: activeUnitId,
          onUnitTap: onUnitTap,
        );

      case 'harf_grid':
        return _HarfGridRow(
          units: units,
          activeUnitId: activeUnitId,
          onUnitTap: onUnitTap,
        );

      case 'muqattaat':
        return _MuqattaatRow(
          units: units,
          activeUnitId: activeUnitId,
          onUnitTap: onUnitTap,
        );

      case 'alphabet':
        return _LetterGrid(
          units: units,
          activeUnitId: activeUnitId,
          onUnitTap: onUnitTap,
        );

      case 'divider':
        return _OrnamentalDivider();

      case 'maddi_table':
        return _TableRow(
          units: units,
          activeUnitId: activeUnitId,
          onUnitTap: onUnitTap,
          isHeader: units.isNotEmpty && units.first.section.contains('headers'),
          isMadd: true,
        );

      case 'madd_word_row':
        return _TableRow(
          units: units,
          activeUnitId: activeUnitId,
          onUnitTap: onUnitTap,
          isMadd: true,
          showBorders: false,
        );

      case 'note':
        return _NoteUnit(
          unit: units.first,
          isActive: activeUnitId == units.first.id,
          onTap: () => onUnitTap(units.first),
        );

      case 'harakat':
      case 'syllable_row':
      case 'word_row':
      case 'generic_row':
      default:
        return _UnitRow(
          units: units,
          activeUnitId: activeUnitId,
          onUnitTap: onUnitTap,
          isLargeText: type == 'harakat',
        );
    }
  }
}

// ============================================================
// NOTE UNIT — Translatable note/instruction at bottom of lesson
// ============================================================

class _NoteUnit extends StatelessWidget {
  final TextUnit unit;
  final bool isActive;
  final VoidCallback onTap;

  const _NoteUnit({
    required this.unit,
    required this.isActive,
    required this.onTap,
  });

  String _getTranslatedText(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final translations = unit.metadata['translations'] as Map<String, dynamic>?;
    if (translations == null) return unit.textContent;

    // Build locale key matching app_localizations.dart convention
    String localeKey;
    if (locale.languageCode == 'uz' && locale.countryCode == 'Cyrl') {
      localeKey = 'uz_Cyrl';
    } else {
      localeKey = locale.languageCode;
    }

    return (translations[localeKey] as String?) ?? unit.textContent;
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isArabicScript = locale.languageCode == 'ar' ||
        (locale.languageCode == 'uz' && locale.countryCode != 'Cyrl');
    final text = _getTranslatedText(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFFF8E1)
              : const Color(0xFFFAF6ED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? const Color(0xFF8D6E63)
                : const Color(0xFFD7CFC0),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: const Color(0x1A8D6E63), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          textDirection: isArabicScript ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(
            fontFamily: isArabicScript ? 'Amiri' : null,
            fontSize: 17,
            height: 1.7,
            color: const Color(0xFF5D4037),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}



class _SectionNavigator extends StatelessWidget {
  final List<Section> sections;
  final int activeIndex;
  final void Function(int) onSectionTap;
  final Function(List<int>)? onSectionPlay;

  const _SectionNavigator({
    required this.sections,
    required this.activeIndex,
    required this.onSectionTap,
    this.onSectionPlay,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'opening_sentence': return Icons.auto_stories_rounded;
      case 'alphabet_grid': return Icons.grid_view_rounded;
      case 'letter_introduction': return Icons.text_fields_rounded;
      case 'letter_drill': return Icons.edit_rounded;
      case 'word_drill': return Icons.spellcheck_rounded;
      case 'divider': return Icons.horizontal_rule_rounded;
      default: return Icons.article_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E3),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF1B5E20).withOpacity(0.12),
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          final isActive = index == activeIndex;

          // Skip divider-type sections in nav
          if (section.sectionType == 'divider') {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onSectionTap(index),
              onLongPress: onSectionPlay != null
                  ? () => onSectionPlay!(section.unitIds)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                        )
                      : null,
                  color: isActive ? null : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: isActive
                      ? null
                      : Border.all(
                          color: const Color(0xFF1B5E20).withOpacity(0.2),
                        ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1B5E20).withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconForType(section.sectionType),
                      size: 16,
                      color: isActive
                          ? Colors.white
                          : const Color(0xFF1B5E20).withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      section.chipLabel,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF1B5E20).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


// ============================================================
// BISMILLAH SENTENCE UNIT
// ============================================================

class _BismillahUnit extends StatefulWidget {
  final TextUnit unit;
  final bool isActive;
  final VoidCallback onTap;

  const _BismillahUnit({
    required this.unit,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_BismillahUnit> createState() => _BismillahUnitState();
}

class _BismillahUnitState extends State<_BismillahUnit>
    with TickerProviderStateMixin {
  bool _isHovered = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  late AnimationController _entryController;
  late Animation<double> _entryScale;
  late Animation<double> _entryOpacity;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entryScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack),
    );
    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.6)),
    );
    _entryController.forward();
  }

  @override
  void didUpdateWidget(_BismillahUnit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _entryController]),
      builder: (context, child) {
        final entryScale = _entryScale.value;
        final entryOpacity = _entryOpacity.value;
        final pulseScale = widget.isActive ? _pulseAnim.value : 1.0;
        final hoverScale = _isHovered ? 1.05 : 1.0;
        final scale = entryScale * pulseScale * hoverScale;

        return Opacity(
          opacity: entryOpacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Semantics(
        label: widget.unit.label,
        button: true,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isActive
                      ? [
                          AppColors.primary.withOpacity(0.12),
                          AppColors.primary.withOpacity(0.06),
                        ]
                      : _isHovered
                          ? [
                              AppColors.primary.withOpacity(0.06),
                              AppColors.primary.withOpacity(0.02),
                            ]
                          : [Colors.transparent, Colors.transparent],
                ),
                boxShadow: _isHovered || widget.isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.18),
                          blurRadius: 32,
                          spreadRadius: 4,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
                border: Border.all(
                  color: widget.isActive
                      ? AppColors.primary.withOpacity(0.25)
                      : _isHovered
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Builder(
                builder: (context) {
                  final sw = MediaQuery.of(context).size.width;
                  final fontSize = sw < 400 ? 26.0 : 40.0;
                  return Text(
                    widget.unit.textContent,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ScheherazadeNew',
                      fontSize: fontSize,
                      height: 2.0,
                      color: const Color(0xFF1B5E20),
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TITLE UNIT (section headers like harakat letter intro)
// ============================================================

class _TitleUnit extends StatefulWidget {
  final TextUnit unit;
  final bool isActive;
  final VoidCallback onTap;

  const _TitleUnit({
    required this.unit,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_TitleUnit> createState() => _TitleUnitState();
}

class _TitleUnitState extends State<_TitleUnit>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _entryOpacity;
  late Animation<double> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _entrySlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final fontSize = sw < 400 ? 34.0 : 44.0;

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Opacity(
          opacity: _entryOpacity.value,
          child: Transform.translate(
            offset: Offset(0, _entrySlide.value),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.isActive
                  ? [
                      AppColors.primary.withOpacity(0.18),
                      AppColors.primary.withOpacity(0.08),
                    ]
                  : [
                      AppColors.primary.withOpacity(0.10),
                      AppColors.primary.withOpacity(0.04),
                    ],
            ),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.primary.withOpacity(0.35)
                  : AppColors.primary.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(widget.isActive ? 0.15 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Small decorative top ornament
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.primary.withOpacity(0.25),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.diamond_outlined,
                    size: 14,
                    color: AppColors.primary.withOpacity(0.4),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Title text
              Text(
                widget.unit.textContent,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: fontSize,
                  height: 1.8,
                  color: widget.isActive
                      ? AppColors.primary
                      : const Color(0xFF1B5E20),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              // Bottom ornament
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.primary.withOpacity(0.25),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.diamond_outlined,
                    size: 14,
                    color: AppColors.primary.withOpacity(0.4),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LETTER GRID (alphabet grid with rows/cols)
// ============================================================

class _LetterGrid extends StatefulWidget {
  final List<TextUnit> units;
  final int? activeUnitId;
  final Function(TextUnit) onUnitTap;

  const _LetterGrid({
    required this.units,
    this.activeUnitId,
    required this.onUnitTap,
  });

  @override
  State<_LetterGrid> createState() => _LetterGridState();
}

class _LetterGridState extends State<_LetterGrid>
    with SingleTickerProviderStateMixin {
  int? _hoveredUnitId;
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = <int, List<TextUnit>>{};
    for (final unit in widget.units) {
      final row = (unit.grid?['row'] as int?) ?? 0;
      rows.putIfAbsent(row, () => []).add(unit);
    }
    for (final row in rows.values) {
      row.sort((a, b) {
        final colA = (a.grid?['col'] as int?) ?? 0;
        final colB = (b.grid?['col'] as int?) ?? 0;
        return colA.compareTo(colB);
      });
    }
    final sortedKeys = rows.keys.toList()..sort();
    final totalUnits = widget.units.length;
    int unitIndex = 0;

    // Find max columns in any row for responsive sizing
    int maxCols = 1;
    for (final row in rows.values) {
      if (row.length > maxCols) maxCols = row.length;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // Cell size = available width / max columns, with margin
        final cellMargin = 4.0; // 2px each side
        final computedSize = (availableWidth - (maxCols * cellMargin * 2)) / maxCols;
        final cellSize = computedSize.clamp(36.0, 64.0);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: sortedKeys.map((rowKey) {
              final rowUnits = rows[rowKey]!;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: rowUnits.map((unit) {
                    final idx = unitIndex++;
                    final staggerDelay = idx / totalUnits;
                    final isHovered = _hoveredUnitId == unit.id;
                    final isActive = widget.activeUnitId == unit.id;
                    final isDimmed = _hoveredUnitId != null &&
                        !isHovered &&
                        widget.activeUnitId != unit.id;

                    return _LetterCell(
                      unit: unit,
                      cellSize: cellSize,
                      isHovered: isHovered,
                      isActive: isActive,
                      isDimmed: isDimmed,
                      staggerController: _staggerController,
                      staggerDelay: staggerDelay,
                      onHoverChanged: (hovered) {
                        setState(() => _hoveredUnitId = hovered ? unit.id : null);
                      },
                      onTap: () => widget.onUnitTap(unit),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ============================================================
// UNIT ROW — Generic row of units (harakat, syllables, words)
// ============================================================

class _UnitRow extends StatefulWidget {
  final List<TextUnit> units;
  final int? activeUnitId;
  final Function(TextUnit) onUnitTap;
  final bool isLargeText;

  const _UnitRow({
    required this.units,
    this.activeUnitId,
    required this.onUnitTap,
    this.isLargeText = false,
  });

  @override
  State<_UnitRow> createState() => _UnitRowState();
}

class _UnitRowState extends State<_UnitRow>
    with SingleTickerProviderStateMixin {
  int? _hoveredUnitId;
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int idx = 0;
    final total = widget.units.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        Widget buildCell(TextUnit unit, int i) {
          final isHovered = _hoveredUnitId == unit.id;
          final isActive = widget.activeUnitId == unit.id;
          final isDimmed = _hoveredUnitId != null &&
              !isHovered &&
              widget.activeUnitId != unit.id;

          // Flex weight: longer words get proportionally more space
          final textLen = unit.textContent.length;
          final flex = textLen > 2 ? textLen : 2;

          return Expanded(
            flex: flex,
            child: _LetterCell(
              unit: unit,
              cellSize: availableWidth / total, // just for height calc
              isLargeText: widget.isLargeText,
              isHovered: isHovered,
              isActive: isActive,
              isDimmed: isDimmed,
              staggerController: _staggerController,
              staggerDelay: i / total,
              onHoverChanged: (hovered) {
                setState(() => _hoveredUnitId = hovered ? unit.id : null);
              },
              onTap: () => widget.onUnitTap(unit),
            ),
          );
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.units.map((unit) {
              return buildCell(unit, idx++);
            }).toList(),
          ),
        );
      },
    );
  }
}

// ============================================================
// SINGLE LETTER/WORD CELL
// ============================================================

class _LetterCell extends StatefulWidget {
  final TextUnit unit;
  final double cellSize;
  final bool isLargeText;
  final bool isHovered;
  final bool isActive;
  final bool isDimmed;
  final AnimationController staggerController;
  final double staggerDelay;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  const _LetterCell({
    required this.unit,
    this.cellSize = 60.0,
    this.isLargeText = false,
    required this.isHovered,
    required this.isActive,
    required this.isDimmed,
    required this.staggerController,
    required this.staggerDelay,
    required this.onHoverChanged,
    required this.onTap,
  });

  @override
  State<_LetterCell> createState() => _LetterCellState();
}

class _LetterCellState extends State<_LetterCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _tapScale;
  late Animation<double> _entryAnimation;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _tapScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _tapController,
      curve: Curves.easeOutCubic,
    ));

    final start = widget.staggerDelay.clamp(0.0, 0.8);
    _entryAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.staggerController,
        curve: Interval(start, (start + 0.3).clamp(0.0, 1.0),
            curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _tapController.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    // Fixed font sizes: titles always 36, exercises always 22/20
    final textLen = widget.unit.textContent.length;
    final isWord = textLen > 2;
    // Fixed cell height: titles 64px, exercises 40px
    final cellHeight = widget.isLargeText ? 64.0 : 40.0;
    // Fixed font sizes — consistent across all rows
    final double fontSize;
    if (widget.isLargeText) {
      fontSize = 36.0; // Dars sarlavhasi — katta, doimiy
    } else {
      fontSize = isWord ? 20.0 : 22.0; // Dars matnlari — doimiy
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_tapScale, _entryAnimation]),
      builder: (context, child) {
        final entry = _entryAnimation.value;
        final tapScale = _tapController.isAnimating ? _tapScale.value : 1.0;
        double hoverScale = widget.isHovered ? 1.15 : 1.0;
        double totalScale = entry * tapScale * hoverScale;

        return Opacity(
          opacity: entry.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: totalScale.clamp(0.0, 2.0),
            child: child,
          ),
        );
      },
      child: Semantics(
        label: widget.unit.label,
        button: true,
        child: MouseRegion(
          onEnter: (_) => widget.onHoverChanged(true),
          onExit: (_) => widget.onHoverChanged(false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _handleTap,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.isDimmed ? 0.5 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                height: cellHeight,
                margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: widget.isActive
                      ? AppColors.primary.withOpacity(0.15)
                      : widget.isHovered
                          ? AppColors.primary.withOpacity(0.07)
                          : Colors.transparent,
                  boxShadow: widget.isHovered
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : widget.isActive
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.18),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                  border: Border.all(
                    color: widget.isActive
                        ? AppColors.primary.withOpacity(0.3)
                        : widget.isHovered
                            ? AppColors.primary.withOpacity(0.15)
                            : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.unit.textContent,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'ScheherazadeNew',
                      fontSize: fontSize,
                      height: 1.3,
                      color: widget.isActive
                          ? AppColors.primary
                          : const Color(0xFF1A1A1A),
                      fontWeight:
                          widget.isActive ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// COVER PAGE — special centered layout for page 1
// ============================================================

// ============================================================
// MUQADDIMA PAGE — Page 2 (Introduction with flowing text)
// ============================================================

class _MuqaddimaPage extends StatefulWidget {
  final List<TextUnit> units;
  final int? activeUnitId;
  final Function(TextUnit) onUnitTap;
  final bool showHeader;

  const _MuqaddimaPage({
    required this.units,
    this.activeUnitId,
    required this.onUnitTap,
    this.showHeader = true,
  });

  @override
  State<_MuqaddimaPage> createState() => _MuqaddimaPageState();
}

class _MuqaddimaPageState extends State<_MuqaddimaPage>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _headerFade;
  late Animation<double> _headerSlide;
  late Animation<double> _bodyFade;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _headerSlide = Tween<double>(begin: -20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    _bodyFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.units.isEmpty) {
      return const Center(child: Text('Sahifa bo\'sh'));
    }

    final headerUnit = widget.showHeader ? widget.units.first : null;
    final bodyUnits = widget.showHeader && widget.units.length > 1
        ? widget.units.sublist(1)
        : widget.units;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 500;
    final horizontalPad = isMobile ? 20.0 : 40.0;
    final headerSize = isMobile ? 32.0 : 42.0;
    final bodySize = isMobile ? 13.0 : 15.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFDF5),
            Color(0xFFF8F3E8),
            Color(0xFFF5EFE0),
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _entryController,
        builder: (context, _) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: horizontalPad,
              right: horizontalPad,
              top: isMobile ? 60 : 70,
              bottom: 80,
            ),
            child: Column(
              children: [
                // ── Decorative top border ──
                Opacity(
                  opacity: _headerFade.value,
                  child: _buildDecorativeLine(),
                ),
                const SizedBox(height: 16),

                // ── "MUQADDIMA" Header (only on page 2) ──
                if (headerUnit != null) ...[
                  Transform.translate(
                    offset: Offset(0, _headerSlide.value),
                    child: Opacity(
                      opacity: _headerFade.value,
                      child: GestureDetector(
                        onTap: () => widget.onUnitTap(headerUnit),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: widget.activeUnitId == headerUnit.id
                                ? AppColors.primary.withOpacity(0.08)
                                : Colors.transparent,
                          ),
                          child: Text(
                            (AppLocalizations.of(context)?.foreword ?? headerUnit.textContent).toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: headerSize,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1B5E20),
                              letterSpacing: 6,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Ornamental divider ──
                  Opacity(
                    opacity: _headerFade.value,
                    child: _buildOrnamentalDivider(),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Body text as flowing paragraph ──
                Opacity(
                  opacity: _bodyFade.value,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 4 : 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFB8860B).withOpacity(0.12),
                      ),
                      color: const Color(0xFFFFFDF5).withOpacity(0.6),
                    ),
                    child: _buildBodyContent(bodyUnits, bodySize, context),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Decorative bottom border ──
                Opacity(
                  opacity: _bodyFade.value,
                  child: _buildDecorativeLine(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds flowing paragraph text where each word is tappable
  Widget _buildFlowingText(List<TextUnit> units, double fontSize) {
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 0,
      runSpacing: 2,
      children: units.map((unit) {
        final isActive = widget.activeUnitId == unit.id;
        // Add space after each word except for punctuation-only words
        final needsSpace = !unit.textContent.startsWith(',') &&
            !unit.textContent.startsWith('.') &&
            !unit.textContent.startsWith(':');

        return GestureDetector(
          onTap: () => widget.onUnitTap(unit),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isActive ? 3 : 1,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.transparent,
            ),
            child: Text(
              needsSpace ? '${unit.textContent} ' : unit.textContent,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: fontSize,
                height: 1.9,
                color: isActive
                    ? const Color(0xFF1B5E20)
                    : const Color(0xFF3E2723).withOpacity(0.85),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Dispatches between interactive word-units (Uz Latin) and translated text
  Widget _buildBodyContent(List<TextUnit> units, double fontSize, BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isUzLatin = locale.languageCode == 'uz' && locale.countryCode != 'Cyrl';

    if (isUzLatin) {
      return _buildFlowingText(units, fontSize);
    }

    final l = AppLocalizations.of(context);
    final translatedBody = l?.forewordBody ?? '';
    if (translatedBody.isEmpty) {
      return _buildFlowingText(units, fontSize);
    }

    return _buildTranslatedBody(translatedBody, fontSize, locale);
  }

  /// Renders full translated foreword as a single styled text block
  Widget _buildTranslatedBody(String text, double fontSize, Locale locale) {
    final isArabic = locale.languageCode == 'ar';

    return SelectableText(
      text,
      textAlign: isArabic ? TextAlign.right : TextAlign.justify,
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      style: TextStyle(
        fontFamily: 'Amiri',
        fontSize: fontSize,
        height: 1.9,
        color: const Color(0xFF3E2723).withOpacity(0.85),
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildOrnamentalDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 50,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                const Color(0xFFB8860B).withOpacity(0.5),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFB8860B).withOpacity(0.5),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '❧',
          style: TextStyle(
            fontSize: 18,
            color: const Color(0xFFB8860B).withOpacity(0.6),
          ),
        ),
        const SizedBox(width: 8),
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFB8860B).withOpacity(0.5),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 50,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFB8860B).withOpacity(0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDecorativeLine() {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFFB8860B).withOpacity(0.25),
            const Color(0xFFB8860B).withOpacity(0.4),
            const Color(0xFFB8860B).withOpacity(0.25),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

// ============================================================
// COVER PAGE (page 1)
// ============================================================

class _CoverPage extends StatefulWidget {
  final List<TextUnit> units;
  final int? activeUnitId;
  final Function(TextUnit) onUnitTap;

  const _CoverPage({
    required this.units,
    this.activeUnitId,
    required this.onUnitTap,
  });

  @override
  State<_CoverPage> createState() => _CoverPageState();
}

class _CoverPageState extends State<_CoverPage>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideUp = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Widget _buildOrnament() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFB8860B).withOpacity(0.5),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFB8860B).withOpacity(0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFB8860B).withOpacity(0.6),
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB8860B).withOpacity(0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFB8860B).withOpacity(0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFB8860B).withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleUnit(TextUnit unit, {required bool isTitle}) {
    final isActive = widget.activeUnitId == unit.id;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 500;

    final titleFontSize = isMobile ? 44.0 : 56.0;
    final subtitleFontSize = isMobile ? 26.0 : 32.0;

    return GestureDetector(
      onTap: () => widget.onUnitTap(unit),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 36,
          vertical: isTitle ? 12 : 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isActive
              ? AppColors.primary.withOpacity(0.08)
              : Colors.transparent,
          border: Border.all(
            color: isActive
                ? AppColors.primary.withOpacity(0.2)
                : Colors.transparent,
          ),
        ),
        child: Text(
          unit.textContent,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Amiri',
            fontSize: isTitle ? titleFontSize : subtitleFontSize,
            fontWeight: isTitle ? FontWeight.w700 : FontWeight.w400,
            color: isTitle
                ? const Color(0xFF1B5E20)
                : const Color(0xFF5D4037),
            height: 1.6,
            letterSpacing: isTitle ? 2.0 : 0.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final units = widget.units;
    
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFDF5),
            Color(0xFFF8F5EC),
            Color(0xFFFFFDF5),
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _entryController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeIn.value,
            child: Transform.translate(
              offset: Offset(0, _slideUp.value),
              child: child,
            ),
          );
        },
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Author label + Arabic name
                Text(
                  AppLocalizations.of(context)?.authorLabel ?? 'Muallif:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF5D4037).withOpacity(0.4),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'أحمد هادى مقصودی',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFB8860B).withOpacity(0.7),
                    letterSpacing: 1.0,
                    height: 1.8,
                  ),
                ),

                const SizedBox(height: 16),

                // Line 1 — معلم ثانی (large calligraphic)
                if (units.isNotEmpty)
                  _buildTitleUnit(units[0], isTitle: true),
                
                _buildOrnament(),
                
                // Line 2 — یاکی (normal subtitle)
                if (units.length > 1)
                  _buildTitleUnit(units[1], isTitle: false),
                
                _buildOrnament(),
                
                // Line 3 — الفباء عربی (large calligraphic)
                if (units.length > 2)
                  _buildTitleUnit(units[2], isTitle: true),
                
                const SizedBox(height: 48),

                // Reader name with headphone icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.headphones_rounded,
                        size: 18, color: const Color(0xFF5D4037).withOpacity(0.45)),
                    const SizedBox(width: 6),
                    Text(
                      '${AppLocalizations.of(context)?.recitedByLabel ?? "O\'qidi:"} Jahongir qori Nematov',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF5D4037).withOpacity(0.45),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
      ),
    );
  }
}

// ============================================================
// ORNAMENTAL DIVIDER
// ============================================================

class _OrnamentalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.primary.withOpacity(0.3),
                    AppColors.primary.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDiamond(),
                const SizedBox(width: 8),
                _buildDiamond(large: true),
                const SizedBox(width: 8),
                _buildDiamond(),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.3),
                    AppColors.primary.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiamond({bool large = false}) {
    final size = large ? 8.0 : 5.0;
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(large ? 0.5 : 0.3),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ============================================================
// ULTRA UI LESSON DIVIDER — Premium separator between lessons
// ============================================================

class _LessonDivider extends StatelessWidget {
  const _LessonDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            // Left gradient line
            Expanded(
              child: Container(
                height: 1.2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.gold.withOpacity(0.12),
                      AppColors.gold.withOpacity(0.35),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            // Center ornament
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildOrnamentDot(3.0, 0.2),
                  const SizedBox(width: 5),
                  _buildOrnamentDot(4.0, 0.3),
                  const SizedBox(width: 5),
                  // Center diamond
                  Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.gold.withOpacity(0.5),
                            AppColors.primary.withOpacity(0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withOpacity(0.15),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  _buildOrnamentDot(4.0, 0.3),
                  const SizedBox(width: 5),
                  _buildOrnamentDot(3.0, 0.2),
                ],
              ),
            ),
            // Right gradient line
            Expanded(
              child: Container(
                height: 1.2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withOpacity(0.35),
                      AppColors.gold.withOpacity(0.12),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrnamentDot(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.gold.withOpacity(opacity),
      ),
    );
  }
}

// ============================================================
// IMAGE OVERLAY RENDERER
// For published pages with uploaded images + bbox-positioned units.
// Renders the source image as background with interactive hotspots.
// ============================================================

class ImageOverlayRenderer extends StatefulWidget {
  final PageDetail page;
  final Function(TextUnit) onUnitTap;
  final int? activeUnitId;

  const ImageOverlayRenderer({
    super.key,
    required this.page,
    required this.onUnitTap,
    this.activeUnitId,
  });

  @override
  State<ImageOverlayRenderer> createState() => _ImageOverlayRendererState();
}

class _ImageOverlayRendererState extends State<ImageOverlayRenderer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.activeUnitId != null) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ImageOverlayRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeUnitId != null && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (widget.activeUnitId == null && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _unitTypeColor(String unitType) {
    switch (unitType.toLowerCase()) {
      case 'letter':
        return const Color(0xFF4CAF50);
      case 'word':
        return const Color(0xFF2196F3);
      case 'sentence':
        return const Color(0xFF9C27B0);
      case 'drill_group':
        return const Color(0xFFFF9800);
      case 'divider':
        return const Color(0xFF607D8B);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imgW = (widget.page.imageWidth ?? 800).toDouble();
    final imgH = (widget.page.imageHeight ?? 1200).toDouble();
    final aspect = imgW / imgH;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFDF5),
            Color(0xFFF8F5EC),
          ],
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Column(
          children: [
            // ── Status badge ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '✨ Native View',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // ── Image with overlays ──
            LayoutBuilder(
              builder: (context, constraints) {
                final containerW = constraints.maxWidth;
                final containerH = containerW / aspect;

                return SizedBox(
                  width: containerW,
                  height: containerH,
                  child: Stack(
                    children: [
                      // ── Background Image ──
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: widget.page.sourceImageUrl!,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFFF5F0E8),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFF5F0E8),
                              child: const Center(
                                child: Icon(Icons.broken_image_rounded,
                                    size: 48, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Interactive hotspot overlays ──
                      ...widget.page.textUnits.map((unit) {
                        final left = unit.bboxX * containerW;
                        final top = unit.bboxY * containerH;
                        final width = unit.bboxW * containerW;
                        final height = unit.bboxH * containerH;
                        final isActive = widget.activeUnitId == unit.id;
                        final color = _unitTypeColor(unit.unitType);

                        return Positioned(
                          left: left,
                          top: top,
                          width: width,
                          height: height,
                          child: _OverlayHotspot(
                            unit: unit,
                            isActive: isActive,
                            color: color,
                            pulseAnim: _pulseAnim,
                            onTap: () => widget.onUnitTap(unit),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 64), // Bottom padding for audio bar
          ],
        ),
      ),
    );
  }
}

// ── Single overlay hotspot ──
class _OverlayHotspot extends StatefulWidget {
  final TextUnit unit;
  final bool isActive;
  final Color color;
  final Animation<double> pulseAnim;
  final VoidCallback onTap;

  const _OverlayHotspot({
    required this.unit,
    required this.isActive,
    required this.color,
    required this.pulseAnim,
    required this.onTap,
  });

  @override
  State<_OverlayHotspot> createState() => _OverlayHotspotState();
}

class _OverlayHotspotState extends State<_OverlayHotspot>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _tapController;
  late Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _tapScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.08), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 35),
    ]).animate(CurvedAnimation(
      parent: _tapController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _tapController.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_tapScale, widget.pulseAnim]),
      builder: (context, child) {
        final tapScale = _tapController.isAnimating ? _tapScale.value : 1.0;
        final pulseOpacity = widget.isActive
            ? 0.15 + (widget.pulseAnim.value * 0.15)
            : 0.0;
        final hoverOpacity = _isHovered ? 0.12 : 0.0;
        final bgOpacity = widget.isActive
            ? pulseOpacity
            : hoverOpacity;

        return Transform.scale(
          scale: tapScale,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _handleTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(bgOpacity.clamp(0.0, 1.0)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: widget.isActive
                        ? widget.color.withOpacity(0.6)
                        : _isHovered
                            ? widget.color.withOpacity(0.3)
                            : Colors.transparent,
                    width: widget.isActive ? 2.0 : 1.5,
                  ),
                  boxShadow: widget.isActive
                      ? [
                          BoxShadow(
                            color: widget.color.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : _isHovered
                          ? [
                              BoxShadow(
                                color: widget.color.withOpacity(0.2),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                ),
                // Show tooltip-like text label for active unit
                child: widget.isActive
                    ? Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Text(
                              widget.unit.textContent,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'ScheherazadeNew',
                                fontSize: 16,
                                color: widget.color.withOpacity(0.9),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TABLE ROW — jadval qatori vertikal chiziqlar bilan
// Supports both simple (3 units = 1 word/cell) and grouped (9 units = 3 words/cell)
// ═══════════════════════════════════════════════════════════════════════

class _TableRow extends StatelessWidget {
  final List<TextUnit> units;
  final int? activeUnitId;
  final ValueChanged<TextUnit> onUnitTap;
  final bool isHeader;
  final bool isMadd;
  final bool showBorders;

  const _TableRow({
    required this.units,
    required this.activeUnitId,
    required this.onUnitTap,
    this.isHeader = false,
    this.isMadd = false,
    this.showBorders = true,
  });

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) return const SizedBox.shrink();

    final cellHeight = isHeader ? 52.0 : 44.0;
    final numUnits = units.length;
    // For borderless rows (madd_word_row), show all words as separate columns
    // For bordered table rows, keep 3-column layout
    final numColumns = showBorders ? 3 : numUnits;

    // Determine if grouped (multi-word per cell) or simple (1 word per cell)
    final bool isGrouped = showBorders && numUnits > numColumns && numUnits % numColumns == 0;
    final wordsPerCell = isGrouped ? numUnits ~/ numColumns : 1;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: showBorders ? BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade300,
              width: 0.5,
            ),
          ),
        ) : null,
        child: IntrinsicHeight(
          child: Row(
            children: _buildColumns(numColumns, wordsPerCell, cellHeight),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildColumns(int numColumns, int wordsPerCell, double cellHeight) {
    final widgets = <Widget>[];
    final actualColumns = (units.length / wordsPerCell).ceil().clamp(1, numColumns);

    for (int col = 0; col < actualColumns; col++) {
      if (col > 0 && showBorders) {
        // Vertical divider between main columns
        widgets.add(Container(
          width: 1,
          color: Colors.grey.shade400,
        ));
      }

      final startIdx = col * wordsPerCell;
      final endIdx = (startIdx + wordsPerCell).clamp(0, units.length);
      final cellUnits = units.sublist(startIdx, endIdx);

      widgets.add(Expanded(
        child: _buildCell(cellUnits, cellHeight),
      ));
    }

    return widgets;
  }

  Widget _buildCell(List<TextUnit> cellUnits, double cellHeight) {
    final fontSize = isHeader ? 30.0 : (cellUnits.length > 1 ? 22.0 : 26.0);

    // Check if any unit in this cell is active
    final hasActive = cellUnits.any((u) => activeUnitId == u.id);

    return Container(
      height: cellHeight,
      decoration: BoxDecoration(
        color: isHeader ? Colors.grey.shade50 : Colors.transparent,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: cellUnits.map((unit) {
          final isActive = activeUnitId == unit.id;
          return Flexible(
            child: GestureDetector(
              onTap: () => onUnitTap(unit),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF1B5E20).withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: (isMadd && _wordHasMadd(unit.textContent))
                    ? _buildMaddText(
                        unit.textContent,
                        fontSize,
                        isActive,
                        isHeader: isHeader,
                      )
                    : Text(
                        unit.textContent,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'ScheherazadeNew',
                          fontSize: fontSize,
                          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? const Color(0xFF1B5E20)
                              : (isHeader
                                  ? Colors.black87
                                  : Colors.black.withOpacity(0.85)),
                          height: 1.3,
                        ),
                      ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Checks whether a word contains a madd (elongation) pattern.
  /// Madd occurs when:
  ///   - Fatha (U+064E) is followed by Alif (U+0627)
  ///   - Damma (U+064F) is followed by Waw (U+0648)
  ///   - Kasra (U+0650) is followed by Ya (U+064A or U+0649)
  static bool _wordHasMadd(String text) {
    final runes = text.runes.toList();
    for (int i = 0; i < runes.length - 1; i++) {
      final cp = runes[i];
      final next = _findNextBaseLetter(runes, i);
      if (next == null) continue;
      // Fatha + Alif = madd
      if (cp == 0x064E && next == 0x0627) return true;
      // Damma + Waw = madd
      if (cp == 0x064F && next == 0x0648) return true;
      // Kasra + Ya (Arabic Yeh U+064A, Alef Maqsura U+0649, or Farsi Yeh U+06CC) = madd
      if (cp == 0x0650 && (next == 0x064A || next == 0x0649 || next == 0x06CC)) return true;
    }
    return false;
  }

  /// Finds the next base letter (non-diacritic) after position [i].
  /// Skips over diacritics (U+064B-U+065F), tatweel (U+0640),
  /// and superscript/subscript alef (U+0670, U+0656).
  static int? _findNextBaseLetter(List<int> runes, int i) {
    for (int j = i + 1; j < runes.length; j++) {
      final r = runes[j];
      // Skip Arabic diacritics range
      if (r >= 0x064B && r <= 0x065F) continue;
      // Skip tatweel
      if (r == 0x0640) continue;
      // Skip superscript/subscript alef
      if (r == 0x0670 || r == 0x0656) continue;
      return r; // This is a base letter
    }
    return null;
  }

  /// Builds Arabic text with madd-specific diacritics using Unicode substitution:
  /// - Fatha (U+064E) → Superscript Alef (U+0670) — standing/vertical fatha
  /// - Kasra (U+0650) → Subscript Alef (U+0656) — standing/vertical kasra
  /// - Damma stays as font's own character (no split, preserves ligatures)
  /// Arabic ligatures are fully preserved since text stays as one unit.
  Widget _buildMaddText(String text, double fontSize, bool isActive, {bool isHeader = false}) {
    final Color textColor = isActive
        ? const Color(0xFF1B5E20)
        : (isHeader ? Colors.black87 : Colors.black.withOpacity(0.85));

    // Special case: standalone اَا (alif+fatha+alif) or اَ (alif+fatha) cell — render as
    // bare alif with a hand-drawn vertical line on top (tikka fatha).
    // Only apply to standalone alif cells (rune length <= 3), not longer words.
    final runes0 = text.runes.toList();
    final isStandaloneAlif = (runes0.length == 3 &&
        runes0[0] == 0x0627 && runes0[1] == 0x064E && runes0[2] == 0x0627) ||
        (runes0.length == 2 && runes0[0] == 0x0627 && runes0[1] == 0x064E);
    if (isStandaloneAlif) {
      final lineHeight = fontSize * 0.22;
      final lineWidth = fontSize * 0.06;
      return Stack(
        alignment: Alignment.topCenter,
        children: [
          Text(
            '\u0627', // bare alif
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'ScheherazadeNew',
              fontSize: fontSize,
              fontWeight: isHeader ? FontWeight.w800 : FontWeight.w600,
              color: textColor,
              height: 1.3,
            ),
          ),
          Positioned(
            top: fontSize * -0.05,
            child: Container(
              width: lineWidth,
              height: lineHeight,
              decoration: BoxDecoration(
                color: textColor,
                borderRadius: BorderRadius.circular(lineWidth / 2),
              ),
            ),
          ),
        ],
      );
    }

    // For all other text: apply per-character Unicode substitution.
    // Only harakats that are followed by a mad letter get tikka style.
    // Non-mad harakats remain unchanged.
    final runes = text.runes.toList();
    final buffer = StringBuffer();
    for (int i = 0; i < runes.length; i++) {
      final cp = runes[i];
      final nextBase = _findNextBaseLetter(runes, i);

      if (cp == 0x064E && nextBase == 0x0627) {
        // Fatha before Alif = madli → Superscript Alef (tikka fatha)
        buffer.write('\u0670');
      } else if (cp == 0x0650 && (nextBase == 0x064A || nextBase == 0x0649 || nextBase == 0x06CC)) {
        // Kasra before Ya (Arabic/Farsi/Maqsura) = madli → Subscript Alef (tikka kasra)
        buffer.write('\u0656');
      } else {
        // Non-mad harakat or any other character → unchanged
        buffer.write(String.fromCharCode(cp));
      }
    }
    final modified = buffer.toString();

    return Text(
      modified,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'ScheherazadeNew',
        fontSize: fontSize,
        fontWeight: isHeader ? FontWeight.w800 : FontWeight.w600,
        color: textColor,
        height: 1.3,
      ),
    );
  }
}

// ============================================================
// SURAH TITLE — Decorative surah header with ornamental border
// ============================================================

class _SurahTitle extends StatelessWidget {
  final TextUnit unit;
  final bool isActive;
  final VoidCallback onTap;

  const _SurahTitle({
    required this.unit,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF1B5E20).withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2E7D32).withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('﴾',
                style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 24,
                    color: const Color(0xFF2E7D32).withOpacity(0.6))),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                unit.textContent,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFF2E7D32),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('﴿',
                style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 24,
                    color: const Color(0xFF2E7D32).withOpacity(0.6))),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AYAT SECTION — Flowing Quranic verse text, large Amiri font
// ============================================================

class _AyatSection extends StatelessWidget {
  final List<TextUnit> units;
  final int? activeUnitId;
  final void Function(TextUnit) onUnitTap;

  const _AyatSection({
    required this.units,
    required this.activeUnitId,
    required this.onUnitTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: units.map((unit) {
          final isActive = unit.id == activeUnitId;
          return GestureDetector(
            onTap: () => onUnitTap(unit),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF1B5E20).withOpacity(0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                unit.textContent,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? const Color(0xFF1B5E20)
                      : Colors.black.withOpacity(0.88),
                  height: 1.8,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
// DUA SECTION — Centered dua/kalima text with premium styling
// ============================================================

class _DuaSection extends StatelessWidget {
  final List<TextUnit> units;
  final int? activeUnitId;
  final void Function(TextUnit) onUnitTap;

  const _DuaSection({
    required this.units,
    required this.activeUnitId,
    required this.onUnitTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: units.map((unit) {
          final isActive = unit.id == activeUnitId;
          return GestureDetector(
            onTap: () => onUnitTap(unit),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF1B5E20).withOpacity(0.07)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                unit.textContent,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? const Color(0xFF1B5E20)
                      : Colors.black.withOpacity(0.85),
                  height: 1.8,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
// EXPLANATION UNIT — Smaller text for explanations/footnotes
// ============================================================

class _ExplanationUnit extends StatelessWidget {
  final List<TextUnit> units;
  final int? activeUnitId;
  final void Function(TextUnit) onUnitTap;

  const _ExplanationUnit({
    required this.units,
    required this.activeUnitId,
    required this.onUnitTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: units.map((unit) {
          final isActive = unit.id == activeUnitId;
          return GestureDetector(
            onTap: () => onUnitTap(unit),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF1B5E20).withOpacity(0.06)
                    : const Color(0xFFF5F5F0).withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF9E9E9E).withOpacity(0.15),
                  width: 0.5,
                ),
              ),
              child: Text(
                unit.textContent,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: isActive
                      ? const Color(0xFF1B5E20)
                      : Colors.black.withOpacity(0.7),
                  height: 1.7,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
// HARF GRID ROW — Arabic letters with names below in grid
// ============================================================

class _HarfGridRow extends StatelessWidget {
  final List<TextUnit> units;
  final int? activeUnitId;
  final void Function(TextUnit) onUnitTap;

  const _HarfGridRow({
    required this.units,
    required this.activeUnitId,
    required this.onUnitTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 6,
          children: units.map((unit) {
            final isActive = unit.id == activeUnitId;
            final label = (unit.metadata['label'] as String?) ?? '';
            return GestureDetector(
              onTap: () => onUnitTap(unit),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 70,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF1B5E20).withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      unit.textContent,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? const Color(0xFF1B5E20)
                            : Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    if (label.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        label,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 13,
                          color: isActive
                              ? const Color(0xFF1B5E20)
                              : Colors.black54,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ============================================================
// MUQATTA'AT ROW — Quranic disconnected letters with readings
// ============================================================

class _MuqattaatRow extends StatelessWidget {
  final List<TextUnit> units;
  final int? activeUnitId;
  final void Function(TextUnit) onUnitTap;

  const _MuqattaatRow({
    required this.units,
    required this.activeUnitId,
    required this.onUnitTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: units.map((unit) {
            final isActive = unit.id == activeUnitId;
            final reading = (unit.metadata['reading'] as String?) ?? '';
            return GestureDetector(
              onTap: () => onUnitTap(unit),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF1B5E20).withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF2E7D32).withOpacity(0.3)
                        : const Color(0xFF9E9E9E).withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      unit.textContent,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFF2E7D32),
                        height: 1.3,
                      ),
                    ),
                    if (reading.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        reading,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 14,
                          color: isActive
                              ? const Color(0xFF1B5E20)
                              : Colors.black54,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ============================================================
// MADD INTRO NOTE — Ultra premium multilingual note widget
// Shows madd (elongation) introduction with 5-language support
// ============================================================

class _MaddIntroNote extends StatelessWidget {
  final List<TextUnit> units;
  final int? activeUnitId;
  final void Function(TextUnit) onUnitTap;

  const _MaddIntroNote({
    required this.units,
    required this.activeUnitId,
    required this.onUnitTap,
  });

  String _getText(TextUnit unit, BuildContext context) {
    final locale = Localizations.localeOf(context);
    final translations = unit.metadata['translations'] as Map<String, dynamic>?;
    if (translations == null) return unit.textContent;

    String localeKey;
    if (locale.languageCode == 'uz' && locale.countryCode == 'Cyrl') {
      localeKey = 'uz_Cyrl';
    } else {
      localeKey = locale.languageCode;
    }

    return (translations[localeKey] as String?) ?? unit.textContent;
  }

  bool _isArabicDisplay(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'ar';
  }

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) return const SizedBox.shrink();

    final isArabic = _isArabicDisplay(context);
    final textDir = isArabic ? TextDirection.rtl : TextDirection.ltr;

    // Separate title and lines using 'role' metadata
    final titleUnit = units.firstWhere(
      (u) => (u.metadata['role'] as String?) == 'title',
      orElse: () => units.first,
    );
    final lineUnits = units.where((u) => (u.metadata['role'] as String?) == 'line').toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF5F0E8),
            const Color(0xFFFAF6F0),
            const Color(0xFFF0EDE5),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFB8A88A).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8D6E63).withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ═══ Title bar with gradient ═══
            GestureDetector(
              onTap: () => onUnitTap(titleUnit),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF5D4037).withOpacity(0.9),
                      const Color(0xFF795548).withOpacity(0.85),
                      const Color(0xFF8D6E63).withOpacity(0.8),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline,
                        color: Color(0xFFFFD54F),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        _getText(titleUnit, context),
                        textAlign: TextAlign.center,
                        textDirection: textDir,
                        style: TextStyle(
                          fontFamily: isArabic ? 'Amiri' : null,
                          fontSize: isArabic ? 22 : 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.4,
                          letterSpacing: isArabic ? 0 : 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline,
                        color: Color(0xFFFFD54F),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ═══ Decorative top accent ═══
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD54F).withOpacity(0),
                    const Color(0xFFFFD54F).withOpacity(0.6),
                    const Color(0xFFFFD54F).withOpacity(0),
                  ],
                ),
              ),
            ),

            // ═══ Content lines ═══
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                children: lineUnits.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final unit = entry.value;
                  final isActive = unit.id == activeUnitId;
                  final text = _getText(unit, context);

                  // Determine icon for each line
                  IconData lineIcon;
                  Color iconColor;
                  switch (idx) {
                    case 0:
                      lineIcon = Icons.info_outline;
                      iconColor = const Color(0xFF1976D2);
                      break;
                    case 1:
                      lineIcon = Icons.format_shapes;
                      iconColor = const Color(0xFF388E3C);
                      break;
                    case 2:
                      lineIcon = Icons.text_increase;
                      iconColor = const Color(0xFFE65100);
                      break;
                    default:
                      lineIcon = Icons.warning_amber_rounded;
                      iconColor = const Color(0xFFD32F2F);
                  }

                  return GestureDetector(
                    onTap: () => onUnitTap(unit),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      margin: EdgeInsets.only(
                        top: idx == 0 ? 0 : 10,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF5D4037).withOpacity(0.06)
                            : Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF5D4037).withOpacity(0.3)
                              : const Color(0xFFD7CFC0).withOpacity(0.5),
                          width: isActive ? 1.5 : 0.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        textDirection: textDir,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(lineIcon, color: iconColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              text,
                              textDirection: textDir,
                              style: TextStyle(
                                fontFamily: isArabic ? 'Amiri' : null,
                                fontSize: isArabic ? 19 : 15.5,
                                fontWeight: FontWeight.w500,
                                color: isActive
                                    ? const Color(0xFF3E2723)
                                    : const Color(0xFF5D4037),
                                height: 1.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
