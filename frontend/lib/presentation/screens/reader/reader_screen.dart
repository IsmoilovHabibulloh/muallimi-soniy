import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/colors.dart';
import '../../../core/constants.dart';
import '../../../domain/providers/book_provider.dart';
import '../../../domain/models/book.dart';
import 'native_page_renderer.dart';

// ─── Audio Playback State ───
enum PlaybackState { idle, playing, paused }

class ReaderScreen extends ConsumerStatefulWidget {
  final int initialPage;
  const ReaderScreen({super.key, required this.initialPage});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late PageController _pageController;
  late AudioPlayer _audioPlayer;

  int _currentPage = 1;
  bool _showOverlay = true;

  // Audio playback
  PlaybackState _playbackState = PlaybackState.idle;
  int _currentUnitIndex = 0; // Which unit is currently playing/highlighted
  int? _activeUnitId; // ID of the highlighted unit
  List<TextUnit> _currentPageUnits = []; // Units on the current page
  List<TextUnit> _playSectionUnits = []; // Section-scoped playback (empty = play all)
  StreamSubscription? _playerStateSubscription;
  bool _isAutoAdvancing = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage - 1);
    _audioPlayer = AudioPlayer();
    // Save initial page on URL navigation
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(AppConstants.keyLastReadPage, widget.initialPage);
    });

    // Listen for audio completion to advance to next unit
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed &&
          _playbackState == PlaybackState.playing) {
        if (_playSectionUnits.isNotEmpty) {
          _advanceSectionUnit();
        } else {
          _advanceToNextUnit();
        }
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _pageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Called when page data loads or page changes ───
  void _updatePageUnits(List<TextUnit> units) {
    if (!mounted) return;
    _currentPageUnits = units
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  // ─── PLAY: Start sequential playback ───
  Future<void> _startPlaying() async {
    if (_currentPageUnits.isEmpty) return;
    _playSectionUnits = []; // Clear section scope = play all
    setState(() => _playbackState = PlaybackState.playing);
    await _playCurrentUnit();
  }

  // ─── PLAY SECTION: Play only units in a specific section ───
  Future<void> _playSectionByIds(List<int> unitIds) async {
    if (_currentPageUnits.isEmpty || unitIds.isEmpty) return;

    // Filter current page units to only those in the section
    _playSectionUnits = _currentPageUnits
        .where((u) => unitIds.contains(u.id))
        .toList();
    if (_playSectionUnits.isEmpty) return;

    _currentUnitIndex = 0;
    setState(() => _playbackState = PlaybackState.playing);
    await _playSectionUnit();
  }

  // ─── Play the current section unit ───
  Future<void> _playSectionUnit() async {
    if (_currentUnitIndex >= _playSectionUnits.length) {
      // Section done
      setState(() {
        _playbackState = PlaybackState.idle;
        _activeUnitId = null;
        _currentUnitIndex = 0;
        _playSectionUnits = [];
      });
      return;
    }

    final unit = _playSectionUnits[_currentUnitIndex];
    if (!mounted) return;
    setState(() => _activeUnitId = unit.id);

    if (unit.audioSegmentUrl != null && unit.audioSegmentUrl!.isNotEmpty) {
      try {
        await _audioPlayer.setUrl(unit.audioSegmentUrl!);
        await _audioPlayer.play();
      } catch (e) {
        debugPrint('Section audio error: $e');
        _advanceSectionUnit();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 400));
      if (_playbackState == PlaybackState.playing) {
        _advanceSectionUnit();
      }
    }
  }

  // ─── Advance to next unit within section ───
  void _advanceSectionUnit() {
    if (_playbackState != PlaybackState.playing) return;
    _currentUnitIndex++;
    _playSectionUnit();
  }

  // ─── Play the current unit's audio ───
  Future<void> _playCurrentUnit() async {
    if (_currentUnitIndex >= _currentPageUnits.length) {
      // All units done on this page → auto-advance
      _autoAdvanceToNextPage();
      return;
    }

    final unit = _currentPageUnits[_currentUnitIndex];
    if (!mounted) return;
    setState(() => _activeUnitId = unit.id);

    if (unit.audioSegmentUrl != null && unit.audioSegmentUrl!.isNotEmpty) {
      try {
        await _audioPlayer.setUrl(unit.audioSegmentUrl!);
        await _audioPlayer.play();
        // Completion handled by _playerStateSubscription
      } catch (e) {
        debugPrint('Audio error: $e');
        // Skip to next unit on error
        _advanceToNextUnit();
      }
    } else {
      // No audio for this unit — briefly highlight, then advance
      await Future.delayed(const Duration(milliseconds: 400));
      if (_playbackState == PlaybackState.playing) {
        _advanceToNextUnit();
      }
    }
  }

  // ─── Advance to next unit ───
  void _advanceToNextUnit() {
    if (_playbackState != PlaybackState.playing) return;

    _currentUnitIndex++;
    if (_currentUnitIndex >= _currentPageUnits.length) {
      _autoAdvanceToNextPage();
    } else {
      _playCurrentUnit();
    }
  }

  // ─── Auto-advance to next page ───
  Future<void> _autoAdvanceToNextPage() async {
    final totalPages = ref.read(bookProvider).valueOrNull?.totalPages ?? 16;
    if (_currentPage >= totalPages) {
      // Book finished
      setState(() {
        _playbackState = PlaybackState.idle;
        _activeUnitId = null;
        _currentUnitIndex = 0;
      });
      return;
    }

    _isAutoAdvancing = true;
    _currentUnitIndex = 0;

    // Animate to next page
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );

    // Wait for page data to load
    await Future.delayed(const Duration(milliseconds: 800));

    if (_playbackState == PlaybackState.playing && mounted) {
      _isAutoAdvancing = false;
      await _playCurrentUnit();
    }
  }

  // ─── PAUSE ───
  void _pause() {
    _audioPlayer.pause();
    setState(() => _playbackState = PlaybackState.paused);
  }

  // ─── RESUME ───
  Future<void> _resume() async {
    setState(() => _playbackState = PlaybackState.playing);

    // If the audio was paused mid-unit, resume it
    if (_audioPlayer.processingState == ProcessingState.ready ||
        _audioPlayer.processingState == ProcessingState.buffering) {
      await _audioPlayer.play();
    } else {
      // Otherwise play current unit from start
      await _playCurrentUnit();
    }
  }

  // ─── STOP ───
  void _stop() {
    _audioPlayer.stop();
    setState(() {
      _playbackState = PlaybackState.idle;
      _activeUnitId = null;
      _currentUnitIndex = 0;
      _playSectionUnits = [];
    });
  }

  // ─── TAP on a specific unit ───
  Future<void> _tapUnit(TextUnit unit) async {
    // If playing sequentially, pause first
    if (_playbackState == PlaybackState.playing) {
      _audioPlayer.stop();
    }

    setState(() {
      _activeUnitId = unit.id;
      // Update index to tapped unit so resume continues from here
      final idx = _currentPageUnits.indexWhere((u) => u.id == unit.id);
      if (idx >= 0) _currentUnitIndex = idx;
    });

    if (unit.audioSegmentUrl != null && unit.audioSegmentUrl!.isNotEmpty) {
      try {
        await _audioPlayer.setUrl(unit.audioSegmentUrl!);
        await _audioPlayer.play();
      } catch (e) {
        debugPrint('Audio error: $e');
      }

      // After single-unit play, clear highlight (unless was in sequential mode)
      _audioPlayer.playerStateStream.first.then((state) {
        if (state.processingState == ProcessingState.completed &&
            _playbackState != PlaybackState.playing &&
            mounted) {
          setState(() => _activeUnitId = null);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = ref.watch(bookProvider).valueOrNull?.totalPages ?? 16;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ═══ Page viewer ═══
          PageView.builder(
            controller: _pageController,
            itemCount: totalPages,
            physics: _playbackState == PlaybackState.playing
                ? const NeverScrollableScrollPhysics()
                : null,
            onPageChanged: (index) {
              final newPage = index + 1;
              setState(() {
                _currentPage = newPage;
                if (!_isAutoAdvancing) {
                  _currentUnitIndex = 0;
                  _activeUnitId = null;
                }
              });
              // Save last read page
              SharedPreferences.getInstance().then((prefs) {
                prefs.setInt(AppConstants.keyLastReadPage, newPage);
              });
            },
            itemBuilder: (context, index) {
              final pageNumber = index + 1;
              return _PageView(
                pageNumber: pageNumber,
                onUnitTap: _tapUnit,
                activeUnitId: _activeUnitId,
                onBackgroundTap: () {
                  setState(() => _showOverlay = !_showOverlay);
                },
                onUnitsLoaded: (units) {
                  if (pageNumber == _currentPage) {
                    _updatePageUnits(units);
                  }
                },
                onSectionPlay: _playSectionByIds,
              );
            },
          ),

          // ═══ Top overlay — page title ═══
          if (_showOverlay)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  right: 16,
                  bottom: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).scaffoldBackgroundColor,
                      Theme.of(context)
                          .scaffoldBackgroundColor
                          .withOpacity(0),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        _stop();
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Text(
                        'Sahifa $_currentPage / $totalPages',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

          // ═══ Bottom Audio Bar ═══
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _AudioBar(
              playbackState: _playbackState,
              currentUnitIndex: _currentUnitIndex,
              totalUnits: _currentPageUnits.length,
              currentPage: _currentPage,
              totalPages: totalPages,
              onPlay: () {
                if (_playbackState == PlaybackState.paused) {
                  _resume();
                } else {
                  _startPlaying();
                }
              },
              onPause: _pause,
              onStop: _stop,
              onPageSliderChanged: (page) {
                _stop();
                _pageController.jumpToPage(page - 1);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// AUDIO BAR — Premium bottom controls
// ════════════════════════════════════════════════════════

class _AudioBar extends StatelessWidget {
  final PlaybackState playbackState;
  final int currentUnitIndex;
  final int totalUnits;
  final int currentPage;
  final int totalPages;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final ValueChanged<int> onPageSliderChanged;

  const _AudioBar({
    required this.playbackState,
    required this.currentUnitIndex,
    required this.totalUnits,
    required this.currentPage,
    required this.totalPages,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onPageSliderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isPlaying = playbackState == PlaybackState.playing;
    final isPaused = playbackState == PlaybackState.paused;
    final isActive = isPlaying || isPaused;

    return Container(
      padding: EdgeInsets.only(
        bottom: bottomPadding + 8,
        top: 12,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Theme.of(context).scaffoldBackgroundColor,
            Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            Theme.of(context).scaffoldBackgroundColor.withOpacity(0),
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Unit progress (only when active) ──
          if (isActive && totalUnits > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalUnits > 0
                          ? (currentUnitIndex + 1) / totalUnits
                          : 0,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary.withOpacity(0.7),
                      ),
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${currentUnitIndex + 1} / $totalUnits',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // ── Controls row ──
          Row(
            children: [
              // Page number
              Text(
                '$currentPage',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              // Page slider
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.primary.withOpacity(0.15),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withOpacity(0.12),
                  ),
                  child: Slider(
                    value: currentPage.toDouble(),
                    min: 1,
                    max: totalPages.toDouble(),
                    divisions: totalPages > 1 ? totalPages - 1 : 1,
                    onChanged: (val) {
                      onPageSliderChanged(val.round());
                    },
                  ),
                ),
              ),

              Text(
                '$totalPages',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(width: 12),

              // ── Audio control buttons ──
              _ControlButton(
                icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                isPrimary: true,
                isActive: isActive,
                onTap: isPlaying ? onPause : onPlay,
                size: 44,
              ),
              const SizedBox(width: 8),
              AnimatedOpacity(
                opacity: isActive ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: _ControlButton(
                  icon: Icons.stop_rounded,
                  isPrimary: false,
                  isActive: isActive,
                  onTap: isActive ? onStop : null,
                  size: 36,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Control Button ──
class _ControlButton extends StatefulWidget {
  final IconData icon;
  final bool isPrimary;
  final bool isActive;
  final VoidCallback? onTap;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.isPrimary,
    required this.isActive,
    this.onTap,
    required this.size,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _scaleController.reverse();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        _scaleController.forward();
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () {
        _scaleController.forward();
        setState(() => _isPressed = false);
      },
      child: AnimatedBuilder(
        animation: _scaleController,
        builder: (context, child) => Transform.scale(
          scale: _scaleController.value,
          child: child,
        ),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isPrimary
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.12),
            boxShadow: widget.isPrimary && widget.isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Icon(
            widget.icon,
            color: widget.isPrimary ? Colors.white : AppColors.primary,
            size: widget.size * 0.55,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// PAGE VIEW — Renders a single page
// ════════════════════════════════════════════════════════

class _PageView extends ConsumerWidget {
  final int pageNumber;
  final Function(TextUnit) onUnitTap;
  final int? activeUnitId;
  final VoidCallback onBackgroundTap;
  final Function(List<TextUnit>) onUnitsLoaded;
  final Function(List<int>)? onSectionPlay;

  const _PageView({
    required this.pageNumber,
    required this.onUnitTap,
    this.activeUnitId,
    required this.onBackgroundTap,
    required this.onUnitsLoaded,
    this.onSectionPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(pageDetailProvider(pageNumber));

    return pageAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (err, _) => Center(
        child: Text('Xatolik: $err',
            style: const TextStyle(color: AppColors.error)),
      ),
      data: (page) {
        if (page == null) {
          return const Center(child: Text('Sahifa topilmadi'));
        }

        // Notify parent about units for audio playback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onUnitsLoaded(page.textUnits);
        });

        // === ALWAYS USE NATIVE RENDERER when text_units exist or page 1 (cover) ===
        if (page.textUnits.isNotEmpty || page.pageNumber == 1) {
          return GestureDetector(
            onTap: onBackgroundTap,
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: NativePageRenderer(
                page: page,
                onUnitTap: onUnitTap,
                activeUnitId: activeUnitId,
                onSectionPlay: onSectionPlay,
              ),
            ),
          );
        }

        // === FALLBACK: Image-only for pages without text_units ===
        return GestureDetector(
          onTap: onBackgroundTap,
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: page.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: page.imageUrl!,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image_rounded, size: 48),
                          const SizedBox(height: 8),
                          Text('Rasm yuklanmadi',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  )
                : const Center(child: Text('Sahifa topilmadi')),
          ),
        );
      },
    );
  }
}
