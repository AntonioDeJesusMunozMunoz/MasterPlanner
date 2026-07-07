// This file is extracted from the app's timeline implementation and minimally
// refactored to compile inside a package. Public API remains similar.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

typedef TimelineEventTap = void Function(TimelineEvent event);
typedef EventMarkerWidgetBuilder = Widget Function(
  BuildContext context,
  TimelineEvent event,
  EventMarkerInfo info,
);
typedef EventMarkerShapePainter = void Function(
  Canvas canvas,
  TimelineEvent event,
  EventMarkerInfo info,
);
typedef TickShapePainter = void Function(
  Canvas canvas,
  TickInfo tick,
  TickDrawContext ctx,
);

/// Positional data for event markers supplied to the builder/painter.
class EventMarkerInfo {
  final Offset position;
  final double zoom;
  final double pxPerMs;
  final double axisCenterCross;
  final bool vertical;
  final Size canvasSize;
  final double markerScale;
  // Stacking and visibility
  final int stackIndex;
  final int stackCount;
  final double opacity;
  // Sticky/clamp state (true if clamped to viewport edge)
  final bool stickyClamped;
  const EventMarkerInfo({
    required this.position,
    required this.zoom,
    required this.pxPerMs,
    required this.axisCenterCross,
    required this.vertical,
    required this.canvasSize,
    required this.markerScale,
    required this.stackIndex,
    required this.stackCount,
    required this.opacity,
    required this.stickyClamped,
  });
}

/// Information about an individual tick passed to the custom tick painter.
class TickInfo {
  final double positionMainAxis;
  final double centerCrossAxis;
  final double height;
  final bool isMajor;
  final String label;
  final bool vertical;
  const TickInfo({
    required this.positionMainAxis,
    required this.centerCrossAxis,
    required this.height,
    required this.isMajor,
    required this.label,
    required this.vertical,
  });
}

/// Context/config provided to the custom tick painter for convenience.
class TickDrawContext {
  final Size size;
  final Color axisColor;
  final Color minorColor;
  final Offset tickOffset;
  final double tickScale;
  const TickDrawContext({
    required this.size,
    required this.axisColor,
    required this.minorColor,
    required this.tickOffset,
    required this.tickScale,
  });
}

// LOD values used for tick generation/label styling. `all` is a special key
// that can be used in `labelStyleByLOD` to apply a style to every LOD, and a
// more granular LOD (e.g. `year`) can still override it.
enum TimeScaleLOD {
  all,
  hour,
  day,
  week,
  month,
  year,
  decade,
  century,
  millennium,
}

class TimelineEvent {
  final DateTime date;
  final DateTime? endDate; // If provided, event spans a range
  final String title;
  final String? description;
  // Optional per-event marker positioning/scaling overrides
  final Offset? markerOffset;
  final double? markerScale;
  // Optional per-event alignment and behavior
  final EventLabelAlign? labelAlign; // For ranged events
  final bool? stickyLabel; // clamp to edge while span is in view
  final bool? stickyKeepFullyVisible; // if true, offset/clamp using extent
  final double? markerMainExtentPx; // estimated width/height along main axis
  final bool? showPole; // draw a pole from axis to marker
  final int importance; // higher = preferred to show when crowded
  final Color? spanColor; // optional per-event span color
  final Color? poleColor; // optional per-event pole color
  final Color? markerColor; // optional per-event default marker color
  final double? fadedOpacity; // per-event fade override when stacked out
  const TimelineEvent({
    required this.date,
    this.endDate,
    required this.title,
    this.description,
    this.markerOffset,
    this.markerScale,
    this.labelAlign,
    this.stickyLabel,
    this.stickyKeepFullyVisible,
    this.markerMainExtentPx,
    this.showPole,
    this.importance = 0,
    this.spanColor,
    this.poleColor,
    this.markerColor,
    this.fadedOpacity,
  });
}

/// Alignment for a ranged event's label when sticky behavior is enabled.
enum EventLabelAlign { left, right }

class TimelineWidget extends StatefulWidget {
  final double height;
  final List<TimelineEvent> events;
  final double minZoom;
  final double maxZoom;
  final double initialZoom;
  final ViewportController viewportController;
  final double basePixelsPerMillisecond;
  // Orientation of the time axis. Horizontal by default.
  final Axis orientation;
  final TimeScaleLOD? minLOD;
  final TimeScaleLOD? maxLOD;
  final TimeScaleLOD? minZoomLOD;
  final TimeScaleLOD? maxZoomLOD;
  final Color backgroundColor;
  final Color timelineColor;
  final Color eventColor;
  final Color tickLabelColor;
  // Thickness controls
  final double axisThickness;
  final double majorTickThickness;
  final double minorTickThickness;
  // Minor tick color override
  final Color? minorTickColor;
  // Optional per-LOD label styles
  final Map<TimeScaleLOD, TextStyle>? labelStyleByLOD;
  // Optional base style for all tick labels (merged before styleByLOD)
  final TextStyle? tickLabelStyle;
  // Optional explicit font family override for tick labels (applied last)
  final String? tickLabelFontFamily;
  // Render every Nth major label (1 = all)
  final int labelStride;
  final Function(double)? onZoomChanged;
  final TimelineEventTap? onEventTap;
  final bool debugMode;
  // Event marker customization
  final EventMarkerWidgetBuilder? eventMarkerBuilder;
  final EventMarkerShapePainter? eventMarkerPainter;
  // Default positioning for event markers when not provided per-event
  final Offset eventMarkerOffset;
  final double eventMarkerScale;
  // Event range indicator (spans) and poles
  final bool showEventSpans;
  final double eventSpanThickness;
  final Color? eventSpanColor; // default derives from eventColor with opacity
  // Optional short poles at the start and end of spans
  final bool showSpanEndPoles;
  final double spanEndPoleThickness; // 0.0 = hairline
  final bool showEventPole; // can be overridden per-event
  final double eventPoleThickness;
  final Color? eventPoleColor;
  // Estimated marker extent along main axis when clamping sticky labels
  final double defaultStickyMarkerExtentPx;
  // Marker stacking/fading
  final bool enableMarkerStacking;
  final int markerMaxStackLayers;
  final double markerStackSpacing;
  final double markerClusterPx;
  final double markerFadedOpacity;
  // Stacking lane behavior
  final bool stackAlternateLanes; // alternate lanes above/below (or left/right)
  // Tick customization
  final TickShapePainter? tickPainter;
  final Offset tickOffset;
  final double tickScale;
  // Show default round event markers when no custom painter is provided.
  // Set to false to hide original markers (useful when supplying widgets).
  final bool showDefaultEventMarker;
  // Fisheye lens configuration
  final bool enableFisheye;
  // Max stretch/scale factor at the cursor (>= 1.0)
  final double fisheyeIntensity;
  // Pixel radius of the lens influence along the main axis
  final double fisheyeRadiusPx;
  // Controls falloff sharpness (>= 1.0). Higher = sharper falloff
  final double fisheyeHardness;
  // Whether to scale tick height by lens and event marker size respectively
  final bool fisheyeScaleTicks;
  final bool fisheyeScaleMarkers;
  // Whether to scale tick label font size by lens
  final bool fisheyeScaleLabels;
  // Lens UX parameters
  // Enter/exit animation durations in milliseconds
  final int fisheyeEnterMs;
  final int fisheyeExitMs;
  // Smoothing factor (per ~16ms frame) for lens center following [0..1]
  final double fisheyeFollowAlpha;
  // Activation toggles
  final bool fisheyeActivateOnHover;
  final bool fisheyeActivateOnLongPress;
  // Visual indicator under cursor and edge feather opacity
  final bool fisheyeShowIndicator;
  final double fisheyeEdgeFeatherOpacity;
  // Lens color override and glow highlighting under the lens
  final Color? fisheyeColor;
  final bool fisheyeGlowEnabled;
  final Color? fisheyeGlowColor;
  final double fisheyeGlowOpacity;
  // Multiplier applied to lens radius for glow reach
  final double fisheyeGlowRadiusMultiplier;
  // Gaussian blur for glow softness (sigma)
  final double fisheyeGlowBlurSigma;
  // Blending modes for lens visuals
  final BlendMode? fisheyeBlendMode; // indicator + feather
  final BlendMode? fisheyeGlowBlendMode;
  // Draw glow/indicator above everything (including event widgets)
  final bool fisheyeGlowOnTop;

  const TimelineWidget({
    super.key,
    required this.viewportController,
    this.height = 120.0,
    this.events = const [],
    this.minZoom = 0.5,
    this.maxZoom = 3.0,
    this.initialZoom = 1.0,
    this.basePixelsPerMillisecond = 0.00002,
    this.orientation = Axis.horizontal,
    this.minLOD,
    this.maxLOD,
    this.minZoomLOD,
    this.maxZoomLOD,
    this.backgroundColor = Colors.white,
    this.timelineColor = Colors.blue,
    this.eventColor = Colors.red,
    this.tickLabelColor = const Color(0xFF666666),
    this.axisThickness = 2.0,
    this.majorTickThickness = 2.0,
    this.minorTickThickness = 1.0,
    this.minorTickColor,
    this.labelStyleByLOD,
    this.tickLabelStyle,
    this.tickLabelFontFamily,
    this.labelStride = 1,
    this.onZoomChanged,
    this.onEventTap,
    this.debugMode = false,
    this.eventMarkerBuilder,
    this.eventMarkerPainter,
    this.eventMarkerOffset = Offset.zero,
    this.eventMarkerScale = 1.0,
    this.showEventSpans = true,
    this.eventSpanThickness = 4.0,
    this.eventSpanColor,
    this.showSpanEndPoles = false,
    this.spanEndPoleThickness = 0.0,
    this.showEventPole = false,
    this.eventPoleThickness = 1.0,
    this.eventPoleColor,
    this.defaultStickyMarkerExtentPx = 80.0,
    this.enableMarkerStacking = true,
    this.markerMaxStackLayers = 3,
    this.markerStackSpacing = 14.0,
    this.markerClusterPx = 36.0,
    this.markerFadedOpacity = 0.18,
    this.stackAlternateLanes = false,
    this.tickPainter,
    this.tickOffset = Offset.zero,
    this.tickScale = 1.0,
    this.showDefaultEventMarker = true,
    this.enableFisheye = false,
    this.fisheyeIntensity = 1.8,
    this.fisheyeRadiusPx = 120.0,
    this.fisheyeHardness = 2.0,
    this.fisheyeScaleTicks = true,
    this.fisheyeScaleMarkers = true,
    this.fisheyeScaleLabels = true,
    this.fisheyeEnterMs = 120,
    this.fisheyeExitMs = 120,
    this.fisheyeFollowAlpha = 0.25,
    this.fisheyeActivateOnHover = true,
    this.fisheyeActivateOnLongPress = true,
    this.fisheyeShowIndicator = true,
    this.fisheyeEdgeFeatherOpacity = 0.12,
    this.fisheyeColor,
    this.fisheyeGlowEnabled = false,
    this.fisheyeGlowColor,
    this.fisheyeGlowOpacity = 0.08,
    this.fisheyeGlowRadiusMultiplier = 1.0,
    this.fisheyeGlowBlurSigma = 16.0,
    this.fisheyeBlendMode,
    this.fisheyeGlowBlendMode,
    this.fisheyeGlowOnTop = false,
  });

  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget>
    with TickerProviderStateMixin {
  double _panOffset = 0;
  double _lastViewExtent = 0; // length along the main axis
  double _effectiveMinZoom = 0.5, _effectiveMaxZoom = 3.0;
  double? _initialCenterMs;
  double? _lensCenterMain; // smoothed pointer position along main axis
  double? _lensTargetMain; // raw target pointer position along main axis
  late final Ticker _lensTicker;
  late final AnimationController _lensActivationCtrl;
  Duration _lastLensTick = Duration.zero;
  // Cached per-frame event layouts shared by painter and overlay
  List<_EventLayout> _eventLayouts = const [];

  @override
  void initState() {
    super.initState();
    widget.viewportController.setZoom(widget.initialZoom);
    _applyZoomLODExtents();
    // Sync state whenever the controller is changed programmatically
    widget.viewportController.addListener(_onControllerChanged);
    _lensActivationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 120),
      value: 0,
    );
    _lensTicker = createTicker(_onLensTick)..start();
  }

  /// Called whenever [ViewportController] notifies — keeps local state in sync
  /// with programmatic pan/zoom changes from outside the widget.
  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {
      _panOffset = widget.viewportController.panOffset;
    });
  }

  List<_EventLayout> _computeEventLayouts(Size size, bool vertical) {
    final List<_EventLayout> result = [];
    final double centerCross = vertical ? size.width / 2 : size.height / 2;
    final double viewExtent = vertical ? size.height : size.width;
    final double scale = widget.basePixelsPerMillisecond * widget.viewportController.zoom;
    final double leftMs = -_panOffset / scale;
    final bool lensActive = widget.enableFisheye &&
        _lensCenterMain != null &&
        _lensActivationCtrl.value > 0;

    double factorAt(double mainPx) {
      if (!lensActive) return 1.0;
      final dx = (mainPx - _lensCenterMain!).abs();
      final t = (dx / widget.fisheyeRadiusPx).clamp(0.0, 1.0);
      final falloff = math.pow(1.0 - t, widget.fisheyeHardness).toDouble();
      return 1.0 +
          (widget.fisheyeIntensity - 1.0) * falloff * _lensActivationCtrl.value;
    }

    double mapMain(double v) {
      if (!lensActive) return v;
      final f = factorAt(v);
      return _lensCenterMain! + (v - _lensCenterMain!) * f;
    }

    double toMainPx(DateTime dt) =>
        (dt.millisecondsSinceEpoch.toDouble() - leftMs) * scale;

    // Build initial entries
    for (final ev in widget.events) {
      final double mainPos = toMainPx(ev.date.toUtc());
      final double mappedMain = mapMain(mainPos);
      final double localScale =
          widget.enableFisheye && widget.fisheyeScaleMarkers
              ? factorAt(mainPos)
              : 1.0;
      final Offset baseOffset = (ev.markerOffset ?? widget.eventMarkerOffset);
      bool hasSpan = ev.endDate != null;
      double spanStart = 0, spanEnd = 0;
      double spanStartMapped = 0, spanEndMapped = 0;
      if (hasSpan) {
        final DateTime endUtc = ev.endDate!.toUtc();
        final double a = toMainPx(ev.date.toUtc());
        final double b = toMainPx(endUtc);
        spanStart = math.min(a, b);
        spanEnd = math.max(a, b);
        spanStartMapped = mapMain(spanStart);
        spanEndMapped = mapMain(spanEnd);
      }

      // Sticky behavior for ranged events
      bool stickyEnabled = hasSpan ? (ev.stickyLabel ?? true) : false;
      final EventLabelAlign align = ev.labelAlign ?? EventLabelAlign.right;
      double markerMain = mappedMain;
      bool stickyClamped = false;
      if (stickyEnabled) {
        final double startClamp = spanStartMapped.clamp(0.0, viewExtent);
        final double endClamp = spanEndMapped.clamp(0.0, viewExtent);
        final bool intersects =
            spanEndMapped >= 0 && spanStartMapped <= viewExtent;
        if (intersects) {
          // Estimate marker main-axis extent to keep fully visible at the edge
          final double estimatedExtent =
              (ev.markerMainExtentPx ?? widget.defaultStickyMarkerExtentPx);
          final double scaledExtent =
              estimatedExtent * (widget.fisheyeScaleMarkers ? localScale : 1.0);
          final double mainUserOffset =
              vertical ? baseOffset.dy : baseOffset.dx;
          if (align == EventLabelAlign.left) {
            markerMain = startClamp -
                (ev.stickyKeepFullyVisible ?? true ? mainUserOffset : 0.0);
          } else {
            final double edge = endClamp;
            markerMain = (ev.stickyKeepFullyVisible ?? true)
                ? (edge - scaledExtent) - mainUserOffset
                : edge;
          }
          if (ev.stickyKeepFullyVisible ?? true) {
            markerMain = markerMain.clamp(0.0, viewExtent - scaledExtent);
          }
          stickyClamped = (markerMain <= 0.0 || markerMain >= viewExtent);
        } else {
          // Entire span out of view: skip
          continue;
        }
      }

      // Initial cross-axis position (before stacking)
      final double baseCross = centerCross;
      // Build layout; stacking assigned later
      result.add(_EventLayout(
        event: ev,
        markerMain: markerMain,
        axisCenterCross: baseCross,
        baseOffset: baseOffset,
        localScale: localScale,
        hasSpan: hasSpan,
        spanStartClamped:
            hasSpan ? spanStartMapped.clamp(0.0, viewExtent) : 0.0,
        spanEndClamped: hasSpan ? spanEndMapped.clamp(0.0, viewExtent) : 0.0,
        stickyClamped: stickyClamped,
      ));
    }

    // Sort by main position for clustering
    result.sort((a, b) => a.markerMain.compareTo(b.markerMain));

    // Cluster by proximity and assign stack indices by importance
    final double clusterPx = widget.markerClusterPx;
    final int maxLayers = math.max(1, widget.markerMaxStackLayers);
    int i = 0;
    while (i < result.length) {
      int j = i + 1;
      final double anchor = result[i].markerMain;
      while (j < result.length &&
          (result[j].markerMain - anchor).abs() <= clusterPx) {
        j++;
      }
      final group = result.sublist(i, j);
      group.sort((a, b) => b.event.importance.compareTo(a.event.importance));
      final int count = group.length;
      for (int k = 0; k < count; k++) {
        final layout = group[k];
        final int assignedIndex = k;
        layout.stackIndex = math.min(assignedIndex, maxLayers - 1);
        layout.stackCount = count;
        final bool faded = assignedIndex >= maxLayers;
        layout.opacity = faded ? widget.markerFadedOpacity : 1.0;
      }
      i = j;
    }

    // Span layering (avoid overlap by stacking spans along cross-axis)
    final List<_SpanInterval> intervals = [];
    for (final l in result) {
      if (!l.hasSpan) continue;
      intervals.add(_SpanInterval(
        start: l.spanStartClamped,
        end: l.spanEndClamped,
        importance: l.event.importance,
        layout: l,
      ));
    }
    // Greedy layering: sort by start then by higher importance first
    intervals.sort((a, b) {
      final c = a.start.compareTo(b.start);
      if (c != 0) return c;
      return b.importance.compareTo(a.importance);
    });
    // Active layer end positions
    final List<double> layerEnds = [];
    for (final iv in intervals) {
      // find first layer where iv.start > layerEnds[layer]
      int layer = 0;
      bool placed = false;
      for (; layer < layerEnds.length; layer++) {
        if (iv.start > layerEnds[layer]) {
          layerEnds[layer] = iv.end;
          iv.layout.spanStackIndex = layer;
          placed = true;
          break;
        }
      }
      if (!placed) {
        layerEnds.add(iv.end);
        iv.layout.spanStackIndex = layerEnds.length - 1;
      }
      // Fade spans beyond max layers using same rules as markers
      final bool spanFaded = iv.layout.spanStackIndex >= maxLayers;
      final double baseFade =
          iv.layout.event.fadedOpacity ?? widget.markerFadedOpacity;
      iv.layout.spanOpacity = spanFaded ? baseFade.clamp(0.0, 1.0) : 1.0;
    }

    // Compute final marker positions including stacking offset and user offset
    for (final l in result) {
      final int lane = l.stackIndex;
      final double laneDir =
          (widget.stackAlternateLanes && (lane % 2 == 1)) ? -1.0 : 1.0;
      final double crossOffset = widget.markerStackSpacing * lane;
      final double signedOffset = crossOffset * laneDir;
      final double cross = vertical
          ? (l.axisCenterCross + (l.baseOffset.dx)) + signedOffset
          : (l.axisCenterCross + (l.baseOffset.dy)) - signedOffset;
      final double main =
          l.markerMain + (vertical ? l.baseOffset.dy : l.baseOffset.dx);
      l.markerPosition = vertical ? Offset(cross, main) : Offset(main, cross);
      l.markerScale = l.localScale;
    }

    return result;
  }

  void _applyZoomLODExtents() {
    double minZ = widget.minZoom, maxZ = widget.maxZoom;
    if (widget.minZoomLOD != null || widget.maxZoomLOD != null) {
      const targetPx = 90.0;
      double majorMs(TimeScaleLOD lod) {
        switch (lod) {
          case TimeScaleLOD.all:
            return 3600e3;
          case TimeScaleLOD.hour:
            return 3600e3;
          case TimeScaleLOD.day:
            return 24 * 3600e3;
          case TimeScaleLOD.week:
            return 7 * 24 * 3600e3;
          case TimeScaleLOD.month:
            return 30 * 24 * 3600e3;
          case TimeScaleLOD.year:
            return 365 * 24 * 3600e3;
          case TimeScaleLOD.decade:
            return 10 * 365 * 24 * 3600e3;
          case TimeScaleLOD.century:
            return 100 * 365 * 24 * 3600e3;
          case TimeScaleLOD.millennium:
            return 1000 * 365 * 24 * 3600e3;
        }
      }

      double zoomFor(TimeScaleLOD lod) =>
          (targetPx / majorMs(lod)) / widget.basePixelsPerMillisecond;
      if (widget.minZoomLOD != null) minZ = zoomFor(widget.minZoomLOD!);
      if (widget.maxZoomLOD != null) maxZ = zoomFor(widget.maxZoomLOD!);
      if (minZ > maxZ) {
        final t = minZ;
        minZ = maxZ;
        maxZ = t;
      }
    }
    _effectiveMinZoom = minZ;
    _effectiveMaxZoom = maxZ;
    widget.viewportController.setZoom(widget.viewportController.zoom.clamp(minZ, maxZ));
  }

  @override
  void dispose() {
    widget.viewportController.removeListener(_onControllerChanged);
    _lensTicker.dispose();
    _lensActivationCtrl.dispose();
    super.dispose();
  }

  void _onLensTick(Duration elapsed) {
    final double dtMs = _lastLensTick == Duration.zero
        ? 16.0
        : (elapsed - _lastLensTick).inMilliseconds.toDouble().clamp(1.0, 33.0);
    _lastLensTick = elapsed;
    if (!mounted) return;
    if (!widget.enableFisheye) return;
    // Smooth follow toward target
    if (_lensTargetMain != null) {
      if (_lensCenterMain == null) {
        _lensCenterMain = _lensTargetMain;
      } else {
        final double baseAlpha = widget.fisheyeFollowAlpha;
        final double a = 1 - math.pow(1 - baseAlpha, dtMs / 16.0).toDouble();
        _lensCenterMain =
            _lensCenterMain! + (_lensTargetMain! - _lensCenterMain!) * a;
      }
    }
    // Avoid extra repaints if nothing is active
    if (_lensTargetMain == null && _lensActivationCtrl.value == 0.0) return;
    setState(() {});
  }

  void _activateLens() {
    if (!widget.enableFisheye) return;
    _lensActivationCtrl.duration =
        Duration(milliseconds: widget.fisheyeEnterMs);
    _lensActivationCtrl.forward();
  }

  void _deactivateLens() {
    _lensActivationCtrl.reverseDuration =
        Duration(milliseconds: widget.fisheyeExitMs);
    _lensActivationCtrl.reverse();
    _lensTargetMain = null;
  }

  // Keep anchor under cursor/fingers during zoom
  void _zoomAnchored(double factor, double anchorX) {
    if (factor == 1 || !factor.isFinite) return;
    final newZoom = (widget.viewportController.zoom * factor).clamp(
      _effectiveMinZoom,
      _effectiveMaxZoom,
    );
    final base = widget.basePixelsPerMillisecond;
    final oldScale = base * widget.viewportController.zoom;
    final newScale = base * newZoom;
    final leftMsOld = -_panOffset / oldScale;
    final anchorMs = leftMsOld + anchorX / oldScale;
    final newLeftMs = anchorMs - anchorX / newScale;
    final newPan = -newLeftMs * newScale;
    setState(() {
      widget.viewportController.zoom = newZoom;
      _panOffset = newPan;
      // Write back to controller so programmatic readers stay in sync
      widget.viewportController._panOffset = newPan;
      widget.onZoomChanged?.call(widget.viewportController.zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(
        context,
      ).copyWith(physics: const NeverScrollableScrollPhysics()),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) => true,
        child: LayoutBuilder(
          builder: (ctx, cts) {
            final bool vertical = widget.orientation == Axis.vertical;
            final double resolvedMaxWidth =
                cts.maxWidth.isFinite ? cts.maxWidth : widget.height;
            final double resolvedMaxHeight =
                cts.maxHeight.isFinite ? cts.maxHeight : widget.height;
            final double paintWidth =
                vertical ? widget.height : resolvedMaxWidth;
            final double paintHeight =
                vertical ? resolvedMaxHeight : widget.height;
            final double viewExtent = vertical ? paintHeight : paintWidth;
            _lastViewExtent = viewExtent.isFinite ? viewExtent : 0;
            // Keep controller's view extent up to date for programmatic use
            widget.viewportController._viewExtentPx = _lastViewExtent;
            return Listener(
              onPointerSignal: (e) {
                if (e is PointerScrollEvent) {
                  final dy = e.scrollDelta.dy;
                  final dx = e.scrollDelta.dx;
                  double factor = 1.0;
                  if (dy != 0) {
                    factor = math.pow(1.0015, -dy).toDouble();
                  } else if (dx != 0) {
                    factor = math.pow(1.0015, dx).toDouble();
                  }
                  if (factor != 1.0 && factor.isFinite) {
                    final double anchor =
                        vertical ? e.localPosition.dy : e.localPosition.dx;
                    if (widget.enableFisheye && widget.fisheyeActivateOnHover) {
                      _lensTargetMain = anchor;
                      _activateLens();
                    }
                    _zoomAnchored(factor, anchor);
                  }
                }
              },
              onPointerHover: (e) {
                if (!(widget.enableFisheye && widget.fisheyeActivateOnHover))
                  return;
                final double anchor =
                    vertical ? e.localPosition.dy : e.localPosition.dx;
                _lensTargetMain = anchor;
                _activateLens();
              },
              onPointerMove: (e) {
                if (!(widget.enableFisheye && widget.fisheyeActivateOnHover))
                  return;
                final double anchor =
                    vertical ? e.localPosition.dy : e.localPosition.dx;
                _lensTargetMain = anchor;
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _centerOnMidpoint,
                onLongPressStart: (d) {
                  if (!(widget.enableFisheye &&
                      widget.fisheyeActivateOnLongPress)) return;
                  final box = context.findRenderObject() as RenderBox;
                  final local = box.globalToLocal(d.globalPosition);
                  final double anchor = vertical ? local.dy : local.dx;
                  _lensTargetMain = anchor;
                  _activateLens();
                },
                onLongPressMoveUpdate: (d) {
                  if (!(widget.enableFisheye &&
                      widget.fisheyeActivateOnLongPress)) return;
                  final box = context.findRenderObject() as RenderBox;
                  final local = box.globalToLocal(d.globalPosition);
                  final double anchor = vertical ? local.dy : local.dx;
                  _lensTargetMain = anchor;
                },
                onLongPressEnd: (d) {
                  if (!(widget.enableFisheye &&
                      widget.fisheyeActivateOnLongPress)) return;
                  _deactivateLens();
                },
                onTapDown: (d) {
                  if (widget.onEventTap == null) return;
                  final hit = _hitTestEvent(
                    d.localPosition,
                    Size(paintWidth, paintHeight),
                  );
                  if (hit != null) widget.onEventTap!(hit);
                },
                onScaleUpdate: (details) {
                  final box = context.findRenderObject() as RenderBox;
                  final local = box.globalToLocal(details.focalPoint);
                  if (details.scale != 1.0) {
                    final double anchor = vertical ? local.dy : local.dx;
                    _zoomAnchored(details.scale, anchor);
                  } else {
                    final double mainDelta = vertical
                        ? details.focalPointDelta.dy
                        : details.focalPointDelta.dx;
                    final double crossDelta = vertical
                        ? details.focalPointDelta.dx
                        : details.focalPointDelta.dy;
                    final double absMain = mainDelta.abs();
                    final double absCross = crossDelta.abs();
                    if (absCross > absMain && crossDelta != 0) {
                      final factor = math.pow(1.0015, -crossDelta).toDouble();
                      final double anchor = vertical ? local.dy : local.dx;
                      _zoomAnchored(factor, anchor);
                    } else {
                      _panOffset += mainDelta;
                      // Write back to controller so programmatic readers stay in sync
                      widget.viewportController._panOffset = _panOffset;
                      setState(() {});
                    }
                  }
                },
                child: SizedBox(
                  width: paintWidth,
                  height: paintHeight,
                  child: MouseRegion(
                    onExit: (e) {
                      if (!widget.enableFisheye) return;
                      _deactivateLens();
                    },
                    child: ClipRect(
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          // Compute event layouts once per frame for consistency
                          Builder(builder: (context) {
                            _eventLayouts = _computeEventLayouts(
                              Size(paintWidth, paintHeight),
                              vertical,
                            );
                            return const SizedBox.shrink();
                          }),
                          // Axis, grid, ticks, and optionally event shapes
                          CustomPaint(
                            size: Size(paintWidth, paintHeight),
                            painter: _Painter(
                              events: widget.events,
                              zoom: widget.viewportController.zoom,
                              panOffset: _panOffset,
                              timelineColor: widget.timelineColor,
                              eventColor: widget.eventColor,
                              basePxPerMs: widget.basePixelsPerMillisecond,
                              tickLabelColor: widget.tickLabelColor,
                              axisThickness: widget.axisThickness,
                              majorTickThickness: widget.majorTickThickness,
                              minorTickThickness: widget.minorTickThickness,
                              minorTickColor: widget.minorTickColor,
                              labelStyleByLOD: widget.labelStyleByLOD,
                              tickLabelStyle: widget.tickLabelStyle,
                              tickLabelFontFamily: widget.tickLabelFontFamily,
                              labelStride: widget.labelStride,
                              tickPainter: widget.tickPainter,
                              eventMarkerPainter: widget.eventMarkerPainter,
                              eventMarkerOffset: widget.eventMarkerOffset,
                              eventMarkerScale: widget.eventMarkerScale,
                              showEventSpans: widget.showEventSpans,
                              eventSpanThickness: widget.eventSpanThickness,
                              eventSpanColor: widget.eventSpanColor,
                              showSpanEndPoles: widget.showSpanEndPoles,
                              spanEndPoleThickness: widget.spanEndPoleThickness,
                              showEventPole: widget.showEventPole,
                              eventPoleThickness: widget.eventPoleThickness,
                              eventPoleColor: widget.eventPoleColor,
                              enableMarkerStacking: widget.enableMarkerStacking,
                              markerMaxStackLayers: widget.markerMaxStackLayers,
                              markerStackSpacing: widget.markerStackSpacing,
                              markerClusterPx: widget.markerClusterPx,
                              markerFadedOpacity: widget.markerFadedOpacity,
                              layouts: _eventLayouts,
                              stackAlternateLanes: widget.stackAlternateLanes,
                              tickOffset: widget.tickOffset,
                              tickScale: widget.tickScale,
                              showDefaultEventMarker:
                                  widget.showDefaultEventMarker,
                              debug: widget.debugMode,
                              vertical: vertical,
                              lensEnabled: widget.enableFisheye,
                              lensCenterMainAxis: _lensCenterMain,
                              lensIntensity: widget.fisheyeIntensity,
                              lensRadiusPx: widget.fisheyeRadiusPx,
                              lensHardness: widget.fisheyeHardness,
                              lensScaleTicks: widget.fisheyeScaleTicks,
                              lensScaleMarkers: widget.fisheyeScaleMarkers,
                              lensScaleLabels: widget.fisheyeScaleLabels,
                              lensActivation: _lensActivationCtrl.value,
                              showLensIndicator: widget.fisheyeShowIndicator,
                              edgeFeatherOpacity:
                                  widget.fisheyeEdgeFeatherOpacity,
                              blendMode: widget.fisheyeBlendMode,
                              glowBlendMode: widget.fisheyeGlowBlendMode,
                              lensColor: widget.fisheyeColor,
                              glowEnabled: widget.fisheyeGlowEnabled,
                              glowColor: widget.fisheyeGlowColor,
                              glowOpacity: widget.fisheyeGlowOpacity,
                              glowRadiusMultiplier:
                                  widget.fisheyeGlowRadiusMultiplier,
                              glowBlurSigma: widget.fisheyeGlowBlurSigma,
                            ),
                          ),
                          if (widget.eventMarkerBuilder != null)
                            ..._buildEventMarkerWidgets(
                              Size(paintWidth, paintHeight),
                              vertical,
                            ),
                          if (widget.enableFisheye && widget.fisheyeGlowOnTop)
                            IgnorePointer(
                              child: CustomPaint(
                                size: Size(paintWidth, paintHeight),
                                painter: _LensOverlayPainter(
                                  timelineColor: widget.timelineColor,
                                  lensEnabled: widget.enableFisheye,
                                  lensCenterMainAxis: _lensCenterMain,
                                  vertical: vertical,
                                  lensActivation: _lensActivationCtrl.value,
                                  lensRadiusPx: widget.fisheyeRadiusPx,
                                  lensColor: widget.fisheyeColor,
                                  edgeFeatherOpacity:
                                      widget.fisheyeEdgeFeatherOpacity,
                                  showLensIndicator:
                                      widget.fisheyeShowIndicator,
                                  blendMode: widget.fisheyeBlendMode,
                                  glowEnabled: widget.fisheyeGlowEnabled,
                                  glowColor: widget.fisheyeGlowColor,
                                  glowOpacity: widget.fisheyeGlowOpacity,
                                  glowRadiusMultiplier:
                                      widget.fisheyeGlowRadiusMultiplier,
                                  glowBlurSigma: widget.fisheyeGlowBlurSigma,
                                  glowBlendMode: widget.fisheyeGlowBlendMode,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _centerOnMidpoint() {
    if (_lastViewExtent <= 0) return;
    double? targetCenterMs;
    if (widget.events.isNotEmpty) {
      DateTime minDate = widget.events.first.date.toUtc();
      DateTime maxDate = minDate;
      for (final e in widget.events) {
        final d = e.date.toUtc();
        if (d.isBefore(minDate)) minDate = d;
        if (d.isAfter(maxDate)) maxDate = d;
      }
      targetCenterMs =
          (minDate.millisecondsSinceEpoch + maxDate.millisecondsSinceEpoch) /
              2.0;
    } else if (_initialCenterMs != null) {
      targetCenterMs = _initialCenterMs;
    }
    if (targetCenterMs == null) return;

    final base = widget.basePixelsPerMillisecond;
    final scale = base * widget.viewportController.zoom;
    final leftMs = targetCenterMs - (_lastViewExtent / 2) / scale;
    final newPan = -leftMs * scale;
    setState(() {
      _panOffset = newPan;
      widget.viewportController._panOffset = newPan;
    });
  }

  TimelineEvent? _hitTestEvent(Offset p, Size size) {
    for (final layout in _eventLayouts) {
      final ev = layout.event;
      final double localScale = layout.markerScale;
      final Offset pos = layout.markerPosition;
      final double hitRadius =
          10 * (ev.markerScale ?? widget.eventMarkerScale) * localScale;
      if ((p - pos).distance <= hitRadius) return ev;
    }
    return null;
  }

  List<Widget> _buildEventMarkerWidgets(Size size, bool vertical) {
    final List<Widget> children = [];
    if (widget.eventMarkerBuilder == null) return children;
    for (final layout in _eventLayouts) {
      final ev = layout.event;
      final info = EventMarkerInfo(
        position: layout.markerPosition,
        zoom: widget.viewportController.zoom,
        pxPerMs: widget.basePixelsPerMillisecond * widget.viewportController.zoom,
        axisCenterCross: layout.axisCenterCross,
        vertical: vertical,
        canvasSize: size,
        markerScale:
            (ev.markerScale ?? widget.eventMarkerScale) * layout.markerScale,
        stackIndex: layout.stackIndex,
        stackCount: layout.stackCount,
        opacity: layout.opacity,
        stickyClamped: layout.stickyClamped,
      );
      final content = widget.eventMarkerBuilder!(context, ev, info);
      final w = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => widget.onEventTap?.call(ev),
        child: Opacity(opacity: info.opacity, child: content),
      );
      children.add(Positioned(
        left: 0,
        top: 0,
        child: Transform.translate(
          offset: Offset(info.position.dx, info.position.dy),
          child: Transform.scale(scale: info.markerScale, child: w),
        ),
      ));
    }
    return children;
  }
}

// ---------------------------------------------------------------------------
// ViewportController
// ---------------------------------------------------------------------------

/// Controls the timeline's pan and zoom programmatically.
///
/// Basic usage:
/// ```dart
/// final _controller = ViewportController();
///
/// // Jump instantly to a date
/// _controller.jumpTo(DateTime(2024, 6, 15), viewWidth, basePxPerMs);
///
/// // Animated pan
/// await _controller.animateTo(DateTime(1969, 7, 20), viewWidth, basePxPerMs, vsync: this);
///
/// // Animated zoom (anchor stays at viewport center)
/// await _controller.animateZoom(2.5, viewWidth, basePxPerMs, vsync: this);
/// ```
///
/// [viewWidth] (or height for a vertical timeline) can be read from
/// [ViewportController.viewExtentPx] after the widget has been laid out,
/// or you can cache it from your own LayoutBuilder.
class ViewportController extends ChangeNotifier {
  double _panOffset = 0;
  double _zoom = 1.0;

  // Updated by the widget after each layout pass — convenience for callers.
  double _viewExtentPx = 0;

  /// Current pan offset in pixels (positive = scrolled right/down).
  double get panOffset => _panOffset;

  /// Current zoom level.
  double get zoom => _zoom;

  /// The widget's most-recently measured main-axis pixel size.
  /// Valid after the first frame; 0 before then.
  double get viewExtentPx => _viewExtentPx;

  // Internal setter used by the widget without triggering a notify loop.
  set zoom(double v) => _zoom = v;

  // ── Instant controls ────────────────────────────────────────────────────

  /// Set zoom and notify listeners.
  void setZoom(double z) {
    _zoom = z;
    notifyListeners();
  }

  /// Set pan offset and notify listeners.
  void setPanOffset(double p) {
    _panOffset = p;
    notifyListeners();
  }

  void jumpToAndSetZoom(DateTime date, double basePxPerMs, double newZoom) {
    _zoom = newZoom;
    final scale = basePxPerMs * _zoom;
    final leftMs = date.toUtc().millisecondsSinceEpoch.toDouble() - (_viewExtentPx / 2) / scale;
    _panOffset = -leftMs * scale;
    notifyListeners(); // single notify, single redraw
  }

  /// Jump instantly so that [centerMs] (UTC milliseconds) is centered in the
  /// viewport. [viewExtentPx] is the widget's pixel width (horizontal) or
  /// height (vertical). Pass [basePxPerMs] from the widget's parameter.
  void jumpToMs(double centerMs, double viewExtentPx, double basePxPerMs) {
    final scale = basePxPerMs * _zoom;
    final leftMs = centerMs - (viewExtentPx / 2) / scale;
    _panOffset = -leftMs * scale;
    notifyListeners();
  }

  /// Jump instantly to center [date] in the viewport.
  void jumpTo(DateTime date, double viewExtentPx, double basePxPerMs) {
    jumpToMs(
      date.toUtc().millisecondsSinceEpoch.toDouble(),
      viewExtentPx,
      basePxPerMs,
    );
  }

  /// Jump instantly to center [date], using the last known [viewExtentPx]
  /// cached by the widget. Convenient when you don't want to track it yourself.
  void jumpToAuto(DateTime date, double basePxPerMs) {
    jumpTo(date, _viewExtentPx, basePxPerMs);
  }

  // ── Animated controls ───────────────────────────────────────────────────

  /// Animate pan to center [date] in the viewport.
  ///
  /// Pass `vsync: this` from any [State] that mixes in
  /// [TickerProviderStateMixin] or [SingleTickerProviderStateMixin].
  Future<void> animateTo(
    DateTime date,
    double viewExtentPx,
    double basePxPerMs, {
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOut,
  }) {
    final targetMs = date.toUtc().millisecondsSinceEpoch.toDouble();
    final scale = basePxPerMs * _zoom;
    final leftMs = targetMs - (viewExtentPx / 2) / scale;
    final targetPan = -leftMs * scale;
    return _animatePan(targetPan, vsync: vsync, duration: duration, curve: curve);
  }

  /// Animated version of [animateTo] using the cached [viewExtentPx].
  Future<void> animateToAuto(
    DateTime date,
    double basePxPerMs, {
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOut,
  }) {
    return animateTo(
      date,
      _viewExtentPx,
      basePxPerMs,
      vsync: vsync,
      duration: duration,
      curve: curve,
    );
  }

  /// Animate zoom to [newZoom], anchoring the center of the viewport so the
  /// visible midpoint stays fixed during the transition.
  Future<void> animateZoom(
    double newZoom,
    double viewExtentPx,
    double basePxPerMs, {
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 350),
    Curve curve = Curves.easeInOut,
  }) async {
    final startZoom = _zoom;
    final startPan = _panOffset;
    final anchorPx = viewExtentPx / 2;
    final oldScale = basePxPerMs * startZoom;
    final anchorMs = (-startPan / oldScale) + anchorPx / oldScale;

    final ctrl = AnimationController(vsync: vsync, duration: duration);
    final anim = CurvedAnimation(parent: ctrl, curve: curve);

    ctrl.addListener(() {
      final z = lerpDouble(startZoom, newZoom, anim.value)!;
      final newScale = basePxPerMs * z;
      final newLeftMs = anchorMs - anchorPx / newScale;
      _zoom = z;
      _panOffset = -newLeftMs * newScale;
      notifyListeners();
    });

    await ctrl.forward();
    ctrl.dispose();
  }

  /// Animated zoom using the cached [viewExtentPx].
  Future<void> animateZoomAuto(
    double newZoom,
    double basePxPerMs, {
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 350),
    Curve curve = Curves.easeInOut,
  }) {
    return animateZoom(
      newZoom,
      _viewExtentPx,
      basePxPerMs,
      vsync: vsync,
      duration: duration,
      curve: curve,
    );
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  Future<void> _animatePan(
    double targetPan, {
    required TickerProvider vsync,
    required Duration duration,
    required Curve curve,
  }) async {
    final startPan = _panOffset;
    final ctrl = AnimationController(vsync: vsync, duration: duration);
    final anim = CurvedAnimation(parent: ctrl, curve: curve);

    ctrl.addListener(() {
      _panOffset = lerpDouble(startPan, targetPan, anim.value)!;
      notifyListeners();
    });

    await ctrl.forward();
    ctrl.dispose();
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

/// Paints the axis, delegates tick generation/labeling to `_PackageTickManager`,
/// and then draws event markers. Labels are only created for major ticks.
class _Painter extends CustomPainter {
  final List<TimelineEvent> events;
  final double zoom;
  final double panOffset;
  final Color timelineColor;
  final Color eventColor;
  final double basePxPerMs;
  final Color tickLabelColor;
  final double axisThickness;
  final double majorTickThickness;
  final double minorTickThickness;
  final Color? minorTickColor;
  final Map<TimeScaleLOD, TextStyle>? labelStyleByLOD;
  final TextStyle? tickLabelStyle;
  final String? tickLabelFontFamily;
  final int labelStride;
  final TickShapePainter? tickPainter;
  final EventMarkerShapePainter? eventMarkerPainter;
  final Offset eventMarkerOffset;
  final double eventMarkerScale;
  final bool showEventSpans;
  final double eventSpanThickness;
  final Color? eventSpanColor;
  final bool showSpanEndPoles;
  final double spanEndPoleThickness;
  final bool showEventPole;
  final double eventPoleThickness;
  final Color? eventPoleColor;
  final bool enableMarkerStacking;
  final int markerMaxStackLayers;
  final double markerStackSpacing;
  final double markerClusterPx;
  final double markerFadedOpacity;
  final List<_EventLayout> layouts;
  final Offset tickOffset;
  final double tickScale;
  final bool showDefaultEventMarker;
  final bool debug;
  final bool vertical;
  // fisheye
  final bool lensEnabled;
  final double? lensCenterMainAxis;
  final double lensIntensity;
  final double lensRadiusPx;
  final double lensHardness;
  final bool lensScaleTicks;
  final bool lensScaleMarkers;
  final bool lensScaleLabels;
  final double lensActivation;
  final bool showLensIndicator;
  final double edgeFeatherOpacity;
  final Color? lensColor;
  final bool glowEnabled;
  final Color? glowColor;
  final double glowOpacity;
  final double glowRadiusMultiplier;
  final double glowBlurSigma;
  final BlendMode? blendMode;
  final BlendMode? glowBlendMode;
  final bool stackAlternateLanes;

  _Painter({
    required this.events,
    required this.zoom,
    required this.panOffset,
    required this.timelineColor,
    required this.eventColor,
    required this.basePxPerMs,
    required this.tickLabelColor,
    required this.axisThickness,
    required this.majorTickThickness,
    required this.minorTickThickness,
    required this.minorTickColor,
    required this.labelStyleByLOD,
    required this.tickLabelStyle,
    required this.tickLabelFontFamily,
    required this.labelStride,
    required this.tickPainter,
    required this.eventMarkerPainter,
    required this.eventMarkerOffset,
    required this.eventMarkerScale,
    required this.showEventSpans,
    required this.eventSpanThickness,
    required this.eventSpanColor,
    required this.showSpanEndPoles,
    required this.spanEndPoleThickness,
    required this.showEventPole,
    required this.eventPoleThickness,
    required this.eventPoleColor,
    required this.enableMarkerStacking,
    required this.markerMaxStackLayers,
    required this.markerStackSpacing,
    required this.markerClusterPx,
    required this.markerFadedOpacity,
    required this.layouts,
    required this.stackAlternateLanes,
    required this.tickOffset,
    required this.tickScale,
    required this.showDefaultEventMarker,
    required this.debug,
    required this.vertical,
    required this.lensEnabled,
    required this.lensCenterMainAxis,
    required this.lensIntensity,
    required this.lensRadiusPx,
    required this.lensHardness,
    required this.lensScaleTicks,
    required this.lensScaleMarkers,
    required this.lensScaleLabels,
    required this.lensActivation,
    required this.showLensIndicator,
    required this.edgeFeatherOpacity,
    required this.lensColor,
    required this.glowEnabled,
    required this.glowColor,
    required this.glowOpacity,
    required this.glowRadiusMultiplier,
    required this.glowBlurSigma,
    required this.blendMode,
    required this.glowBlendMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerCross = vertical ? size.width / 2 : size.height / 2;
    double mapMain(double v) {
      if (!lensEnabled || lensCenterMainAxis == null) return v;
      final dx = (v - lensCenterMainAxis!).abs();
      final t = (dx / lensRadiusPx).clamp(0.0, 1.0);
      final falloff = math.pow(1.0 - t, lensHardness).toDouble();
      final f = 1.0 + (lensIntensity - 1.0) * falloff * lensActivation;
      return lensCenterMainAxis! + (v - lensCenterMainAxis!) * f;
    }

    double factorAt(double v) {
      if (!lensEnabled || lensCenterMainAxis == null) return 1.0;
      final dx = (v - lensCenterMainAxis!).abs();
      final t = (dx / lensRadiusPx).clamp(0.0, 1.0);
      final falloff = math.pow(1.0 - t, lensHardness).toDouble();
      return 1.0 + (lensIntensity - 1.0) * falloff * lensActivation;
    }

    // Draw base axis line
    final axisPaint = Paint()
      ..color = timelineColor
      ..strokeWidth = axisThickness;
    if (vertical) {
      canvas.drawLine(
        Offset(centerCross, 0),
        Offset(centerCross, size.height),
        axisPaint,
      );
    } else {
      canvas.drawLine(
        Offset(0, centerCross),
        Offset(size.width, centerCross),
        axisPaint,
      );
    }

    final scale = basePxPerMs * zoom;
    final tickManager = _PackageTickManager.instance
      ..initialize(
        axisColor: timelineColor,
        labelColor: tickLabelColor,
        minorColor: (minorTickColor ?? timelineColor.withValues(alpha: 0.7)),
        majorThickness: majorTickThickness,
        minorThickness: minorTickThickness,
      )
      ..setBasePixelsPerMs(basePxPerMs);
    final ticks = tickManager.generateTicks(
      zoom,
      panOffset,
      size,
      vertical: vertical,
    );
    tickManager.renderGrid(canvas, zoom, panOffset, size, vertical: vertical);

    int majorIndex = 0;
    for (final tick in ticks) {
      final mappedX = mapMain(tick.x);
      final localFactor = lensScaleTicks ? factorAt(tick.x) : 1.0;
      final effectiveScale = tickScale * localFactor;
      if (tickPainter != null) {
        final info = TickInfo(
          positionMainAxis: mappedX,
          centerCrossAxis: centerCross,
          height: tick.h * effectiveScale,
          isMajor: tick.isMajor,
          label: tick.label,
          vertical: vertical,
        );
        final ctx = TickDrawContext(
          size: size,
          axisColor: timelineColor,
          minorColor: (minorTickColor ?? timelineColor.withValues(alpha: 0.7)),
          tickOffset: tickOffset,
          tickScale: 1.0,
        );
        tickPainter!(canvas, info, ctx);
      } else {
        final p = tick.isMajor
            ? (Paint()
              ..color = timelineColor
              ..strokeWidth = majorTickThickness)
            : (Paint()
              ..color = (minorTickColor ?? timelineColor.withValues(alpha: 0.7))
              ..strokeWidth = minorTickThickness);
        final double scaledH = tick.h * effectiveScale;
        if (!vertical) {
          canvas.drawLine(
            Offset(
                mappedX + tickOffset.dx, centerCross - scaledH + tickOffset.dy),
            Offset(
                mappedX + tickOffset.dx, centerCross + scaledH + tickOffset.dy),
            p,
          );
        } else {
          canvas.drawLine(
            Offset(
                centerCross - scaledH + tickOffset.dx, mappedX + tickOffset.dy),
            Offset(
                centerCross + scaledH + tickOffset.dx, mappedX + tickOffset.dy),
            p,
          );
        }
      }
      if (tick.isMajor && tick.label.isNotEmpty) {
        if (labelStride > 1 && (majorIndex++ % labelStride != 0)) {
          _PackageTickManager.instance.diagnostics?.labelsDroppedByStride++;
          continue;
        }
        TextStyle style = tickLabelStyle ??
            TextStyle(
              color: tickLabelColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            );
        if (style.color == null) {
          style = style.merge(TextStyle(color: tickLabelColor));
        }
        if (labelStyleByLOD != null) {
          final lod =
              _PackageTickManager.instance._inferLODFromLabel(tick.label);
          final baseForAll = labelStyleByLOD![TimeScaleLOD.all];
          if (baseForAll != null) style = style.merge(baseForAll);
          final specific = labelStyleByLOD![lod];
          if (specific != null) style = style.merge(specific);
        }
        if (tickLabelFontFamily != null && tickLabelFontFamily!.isNotEmpty) {
          style = style.merge(TextStyle(fontFamily: tickLabelFontFamily));
        }
        if (lensEnabled && lensScaleLabels && lensCenterMainAxis != null) {
          final localFactor = factorAt(tick.x);
          final baseSize = style.fontSize ?? 12;
          style = style.copyWith(fontSize: baseSize * localFactor);
        }
        final tp = _PackageTickManager.instance
            ._tp('${tick.label}_${tickLabelColor.toARGB32()}_12_5', style);
        tp.layout();
        if (!vertical) {
          final tx = mappedX + tickOffset.dx - tp.width / 2;
          if (tx <= size.width && tx + tp.width >= 0) {
            tp.paint(
                canvas,
                Offset(
                    tx,
                    centerCross +
                        (tick.h * effectiveScale) +
                        4 +
                        tickOffset.dy));
            _PackageTickManager.instance.diagnostics?.labelsPainted++;
          }
        } else {
          final ty = mappedX + tickOffset.dy - tp.height / 2;
          final double labelX =
              centerCross + (tick.h * effectiveScale) + 4 + tickOffset.dx;
          if (ty <= size.height && ty + tp.height >= 0) {
            tp.paint(canvas, Offset(labelX, ty));
            _PackageTickManager.instance.diagnostics?.labelsPainted++;
          }
        }
      }
    }

    // Debug overlay
    if (debug) {
      final diag = tickManager.diagnostics;
      if (diag != null) {
        final lines = <String>[
          'LOD: ${diag.lod.name}',
          'px/ms: ${diag.pxPerMs.toStringAsFixed(6)}  target: ${diag.targetPx.toStringAsFixed(0)}px',
          'major: ${diag.majorMs ~/ 1000}s (${diag.majorPx.toStringAsFixed(1)} px)  minor: ${diag.minorMs ~/ 1000}s (${diag.minorPx.toStringAsFixed(1)} px)',
          'majors in view: ${diag.numMajor}  minors: ${diag.numMinor}',
          'labels drawn: ${diag.labelsPainted}  skippedByStride: ${diag.labelsDroppedByStride}  stride: $labelStride',
        ];
        final text = lines.join('\n');
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.85),
              fontSize: 12,
              height: 1.2,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: size.width - 8);
        final bg = Paint()..color = Colors.white.withValues(alpha: 0.7);
        final rect = Rect.fromLTWH(4, 4, tp.width + 8, tp.height + 8);
        canvas.drawRect(rect, bg);
        tp.paint(canvas, const Offset(8, 8));
      }
    }

    // Lens indicator and edge feathering
    if (lensEnabled && lensCenterMainAxis != null && lensActivation > 0) {
      final Color baseColor = (lensColor ?? timelineColor);
      final indicatorAlpha = 0.35 * lensActivation;
      if (showLensIndicator && indicatorAlpha > 0) {
        final p = Paint()
          ..color = baseColor.withValues(alpha: indicatorAlpha)
          ..strokeWidth = 1.0
          ..blendMode = (blendMode ?? BlendMode.srcOver);
        if (!vertical) {
          canvas.drawLine(
            Offset(lensCenterMainAxis!, 0),
            Offset(lensCenterMainAxis!, size.height),
            p,
          );
        } else {
          canvas.drawLine(
            Offset(0, lensCenterMainAxis!),
            Offset(size.width, lensCenterMainAxis!),
            p,
          );
        }
      }
      final op = edgeFeatherOpacity * lensActivation;
      if (op > 0) {
        final rect = !vertical
            ? Rect.fromLTWH(
                lensCenterMainAxis! - lensRadiusPx,
                0,
                lensRadiusPx * 2,
                size.height,
              )
            : Rect.fromLTWH(
                0,
                lensCenterMainAxis! - lensRadiusPx,
                size.width,
                lensRadiusPx * 2,
              );
        final shader = (vertical
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      baseColor.withValues(alpha: op),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  )
                : LinearGradient(
                    colors: [
                      Colors.transparent,
                      baseColor.withValues(alpha: op),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ))
            .createShader(rect);
        final paint = Paint()
          ..shader = shader
          ..blendMode = (blendMode ?? BlendMode.srcOver);
        canvas.drawRect(rect, paint);
      }

      if (glowEnabled) {
        final glowBase = (glowColor ?? baseColor)
            .withValues(alpha: glowOpacity * lensActivation);
        final glowPaint = Paint()
          ..color = glowBase
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlurSigma)
          ..blendMode = (glowBlendMode ?? BlendMode.srcOver);
        final double glowRadius =
            lensRadiusPx * (1.0 + glowRadiusMultiplier).clamp(0.0, 3.0);
        if (!vertical) {
          final rectGlow = Rect.fromLTWH(
            lensCenterMainAxis! - glowRadius,
            0,
            glowRadius * 2,
            size.height,
          );
          canvas.drawRRect(
            RRect.fromRectAndCorners(rectGlow),
            glowPaint,
          );
        } else {
          final rectGlow = Rect.fromLTWH(
            0,
            lensCenterMainAxis! - glowRadius,
            size.width,
            glowRadius * 2,
          );
          canvas.drawRRect(
            RRect.fromRectAndCorners(rectGlow),
            glowPaint,
          );
        }
      }
    }

    // Events — spans first (under markers)
    if (showEventSpans) {
      for (final layout in layouts) {
        if (!layout.hasSpan) continue;
        final Color col = layout.event.spanColor ??
            eventSpanColor ??
            eventColor.withValues(alpha: 0.35);
        final double op = layout.spanOpacity;
        final p = Paint()
          ..color = col.withValues(alpha: op)
          ..strokeWidth = eventSpanThickness
          ..strokeCap = StrokeCap.round;
        final double spanCrossOffset =
            markerStackSpacing * layout.spanStackIndex;
        if (!vertical) {
          final int lane = layout.spanStackIndex;
          final double laneDir =
              (stackAlternateLanes && (lane % 2 == 1)) ? -1.0 : 1.0;
          final double y = centerCross +
              (eventMarkerOffset.dy) -
              (spanCrossOffset * laneDir);
          canvas.drawLine(
            Offset(layout.spanStartClamped, y),
            Offset(layout.spanEndClamped, y),
            p,
          );
          if (showSpanEndPoles) {
            final Paint pp = Paint()
              ..color = p.color
              ..strokeWidth =
                  (spanEndPoleThickness <= 0.0 ? 0.0 : spanEndPoleThickness)
              ..strokeCap = StrokeCap.round;
            canvas.drawLine(
              Offset(layout.spanStartClamped, y),
              Offset(layout.spanStartClamped, centerCross),
              pp,
            );
            canvas.drawLine(
              Offset(layout.spanEndClamped, y),
              Offset(layout.spanEndClamped, centerCross),
              pp,
            );
          }
        } else {
          final int lane = layout.spanStackIndex;
          final double laneDir =
              (stackAlternateLanes && (lane % 2 == 1)) ? -1.0 : 1.0;
          final double x = centerCross +
              (eventMarkerOffset.dx) +
              (spanCrossOffset * laneDir);
          canvas.drawLine(
            Offset(x, layout.spanStartClamped),
            Offset(x, layout.spanEndClamped),
            p,
          );
          if (showSpanEndPoles) {
            final Paint pp = Paint()
              ..color = p.color
              ..strokeWidth =
                  (spanEndPoleThickness <= 0.0 ? 0.0 : spanEndPoleThickness)
              ..strokeCap = StrokeCap.round;
            canvas.drawLine(
              Offset(x, layout.spanStartClamped),
              Offset(centerCross, layout.spanStartClamped),
              pp,
            );
            canvas.drawLine(
              Offset(x, layout.spanEndClamped),
              Offset(centerCross, layout.spanEndClamped),
              pp,
            );
          }
        }
      }
    }

    // Optional poles from axis to marker position
    for (final layout in layouts) {
      final bool pole = (layout.event.showPole ?? showEventPole);
      if (!pole) continue;
      final p = Paint()
        ..color = (layout.event.poleColor ??
            eventPoleColor ??
            eventColor.withValues(alpha: 0.6))
        ..strokeWidth = eventPoleThickness;
      if (!vertical) {
        canvas.drawLine(
          Offset(layout.markerMain, centerCross),
          Offset(layout.markerMain, layout.markerPosition.dy),
          p,
        );
      } else {
        canvas.drawLine(
          Offset(centerCross, layout.markerMain),
          Offset(layout.markerPosition.dx, layout.markerMain),
          p,
        );
      }
    }

    // Event markers
    if (eventMarkerPainter != null) {
      for (final layout in layouts) {
        final ev = layout.event;
        final info = EventMarkerInfo(
          position: layout.markerPosition,
          zoom: zoom,
          pxPerMs: scale,
          axisCenterCross: centerCross,
          vertical: vertical,
          canvasSize: size,
          markerScale:
              (ev.markerScale ?? eventMarkerScale) * layout.markerScale,
          stackIndex: layout.stackIndex,
          stackCount: layout.stackCount,
          opacity: layout.opacity,
          stickyClamped: layout.stickyClamped,
        );
        canvas.saveLayer(null, Paint());
        eventMarkerPainter!(canvas, ev, info);
        canvas.restore();
      }
    } else if (showDefaultEventMarker) {
      for (final layout in layouts) {
        final ev = layout.event;
        final double r =
            6 * (ev.markerScale ?? eventMarkerScale) * layout.markerScale;
        final pos = layout.markerPosition;
        final Color base = (ev.markerColor ?? eventColor);
        final double op = ev.fadedOpacity != null && layout.opacity < 1.0
            ? ev.fadedOpacity!.clamp(0.0, 1.0)
            : layout.opacity;
        final p = Paint()..color = base.withValues(alpha: op);
        canvas.drawCircle(pos, r, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old) =>
      old.events != events ||
      old.zoom != zoom ||
      old.panOffset != panOffset ||
      old.tickPainter != tickPainter ||
      old.eventMarkerPainter != eventMarkerPainter ||
      old.layouts != layouts ||
      old.lensEnabled != lensEnabled ||
      old.lensCenterMainAxis != lensCenterMainAxis ||
      old.lensIntensity != lensIntensity ||
      old.lensRadiusPx != lensRadiusPx ||
      old.lensHardness != lensHardness ||
      old.lensScaleTicks != lensScaleTicks ||
      old.lensScaleMarkers != lensScaleMarkers ||
      old.lensScaleLabels != lensScaleLabels;
}

// ---------------------------------------------------------------------------
// Lens overlay painter
// ---------------------------------------------------------------------------

/// Paints only the lens visuals (indicator, feather, glow) to allow stacking
/// them above event widgets when requested.
class _LensOverlayPainter extends CustomPainter {
  final Color timelineColor;
  final bool lensEnabled;
  final double? lensCenterMainAxis;
  final bool vertical;
  final double lensActivation;
  final double lensRadiusPx;
  final Color? lensColor;
  final double edgeFeatherOpacity;
  final bool showLensIndicator;
  final BlendMode? blendMode;
  final bool glowEnabled;
  final Color? glowColor;
  final double glowOpacity;
  final double glowRadiusMultiplier;
  final double glowBlurSigma;
  final BlendMode? glowBlendMode;

  _LensOverlayPainter({
    required this.timelineColor,
    required this.lensEnabled,
    required this.lensCenterMainAxis,
    required this.vertical,
    required this.lensActivation,
    required this.lensRadiusPx,
    required this.lensColor,
    required this.edgeFeatherOpacity,
    required this.showLensIndicator,
    required this.blendMode,
    required this.glowEnabled,
    required this.glowColor,
    required this.glowOpacity,
    required this.glowRadiusMultiplier,
    required this.glowBlurSigma,
    required this.glowBlendMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!lensEnabled || lensCenterMainAxis == null || lensActivation <= 0) {
      return;
    }
    final Color baseColor = (lensColor ?? timelineColor);
    final indicatorAlpha = 0.35 * lensActivation;
    if (showLensIndicator && indicatorAlpha > 0) {
      final p = Paint()
        ..color = baseColor.withValues(alpha: indicatorAlpha)
        ..strokeWidth = 1.0
        ..blendMode = (blendMode ?? BlendMode.srcOver);
      if (!vertical) {
        canvas.drawLine(
          Offset(lensCenterMainAxis!, 0),
          Offset(lensCenterMainAxis!, size.height),
          p,
        );
      } else {
        canvas.drawLine(
          Offset(0, lensCenterMainAxis!),
          Offset(size.width, lensCenterMainAxis!),
          p,
        );
      }
    }
    final op = edgeFeatherOpacity * lensActivation;
    if (op > 0) {
      final rect = !vertical
          ? Rect.fromLTWH(
              lensCenterMainAxis! - lensRadiusPx,
              0,
              lensRadiusPx * 2,
              size.height,
            )
          : Rect.fromLTWH(
              0,
              lensCenterMainAxis! - lensRadiusPx,
              size.width,
              lensRadiusPx * 2,
            );
      final shader = (vertical
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    baseColor.withValues(alpha: op),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                )
              : LinearGradient(
                  colors: [
                    Colors.transparent,
                    baseColor.withValues(alpha: op),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ))
          .createShader(rect);
      final paint = Paint()
        ..shader = shader
        ..blendMode = (blendMode ?? BlendMode.srcOver);
      canvas.drawRect(rect, paint);
    }

    if (glowEnabled) {
      final glowBase = (glowColor ?? baseColor)
          .withValues(alpha: glowOpacity * lensActivation);
      final glowPaint = Paint()
        ..color = glowBase
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlurSigma)
        ..blendMode = (glowBlendMode ?? BlendMode.srcOver);
      final double glowRadius =
          lensRadiusPx * (1.0 + glowRadiusMultiplier).clamp(0.0, 3.0);
      if (!vertical) {
        final rectGlow = Rect.fromLTWH(
          lensCenterMainAxis! - glowRadius,
          0,
          glowRadius * 2,
          size.height,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(rectGlow),
          glowPaint,
        );
      } else {
        final rectGlow = Rect.fromLTWH(
          0,
          lensCenterMainAxis! - glowRadius,
          size.width,
          glowRadius * 2,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(rectGlow),
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LensOverlayPainter old) =>
      old.lensEnabled != lensEnabled ||
      old.lensCenterMainAxis != lensCenterMainAxis ||
      old.vertical != vertical ||
      old.lensActivation != lensActivation ||
      old.lensRadiusPx != lensRadiusPx ||
      old.lensColor != lensColor ||
      old.edgeFeatherOpacity != edgeFeatherOpacity ||
      old.showLensIndicator != showLensIndicator ||
      old.blendMode != blendMode ||
      old.glowEnabled != glowEnabled ||
      old.glowColor != glowColor ||
      old.glowOpacity != glowOpacity ||
      old.glowRadiusMultiplier != glowRadiusMultiplier ||
      old.glowBlurSigma != glowBlurSigma ||
      old.glowBlendMode != glowBlendMode;
}

// ---------------------------------------------------------------------------
// Tick manager
// ---------------------------------------------------------------------------

// Minimal, namespaced copy of the performant tick manager for the package
class _PackageTickManager {
  _PackageTickManager._();
  static final _PackageTickManager instance = _PackageTickManager._();

  final List<_PkgTick> _pool = [];
  final List<_PkgTick> _active = [];
  final Map<String, TextPainter> _tpCache = {};
  _Diagnostics? diagnostics;
  late Paint _major, _minor, _grid;
  bool _init = false;
  double _basePxPerMs = 0.00002;
  Color _labelColor = const Color(0xFF666666);

  void initialize({
    required Color axisColor,
    required Color labelColor,
    required Color minorColor,
    required double majorThickness,
    required double minorThickness,
  }) {
    if (!_init) {
      _major = Paint()
        ..color = axisColor
        ..strokeWidth = majorThickness;
      _minor = Paint()
        ..color = minorColor
        ..strokeWidth = minorThickness;
      _grid = Paint()
        ..color = axisColor.withValues(alpha: 0.25)
        ..strokeWidth = 0.5;
      _labelColor = labelColor;
      _init = true;
    } else {
      _major
        ..color = axisColor
        ..strokeWidth = majorThickness;
      _minor
        ..color = minorColor
        ..strokeWidth = minorThickness;
      _labelColor = labelColor;
    }
  }

  void setBasePixelsPerMs(double v) => _basePxPerMs = v;

  List<_PkgTick> generateTicks(
    double zoom,
    double pan,
    Size size, {
    bool vertical = false,
  }) {
    for (final t in _active) _pool.add(t);
    _active.clear();
    final scale = _basePxPerMs * zoom;
    final leftMs = -pan / scale;
    final mainExtent = vertical ? size.height : size.width;
    final rightMs = leftMs + mainExtent / scale;

    final unit = _pickUnit(scale);

    double ceilTo(double v, double step) {
      final m = v % step;
      return m == 0 ? v : v + (step - m);
    }

    diagnostics = _Diagnostics(
      lod: unit.lod,
      pxPerMs: scale,
      targetPx: 90.0,
      majorMs: unit.majorMs,
      minorMs: unit.minorMs,
    );
    final firstMinor = ceilTo(leftMs, unit.minorMs);
    for (double t = firstMinor; t <= rightMs; t += unit.minorMs) {
      final pos = (t - leftMs) * scale;
      if (vertical) {
        if (pos < -50 || pos > size.height + 50) continue;
      } else {
        if (pos < -50 || pos > size.width + 50) continue;
      }
      _active.add(_get().set(t, pos, false, '', 8));
      diagnostics!.numMinor++;
    }
    final firstMajor = ceilTo(leftMs, unit.majorMs);
    for (double t = firstMajor; t <= rightMs; t += unit.majorMs) {
      final pos = (t - leftMs) * scale;
      if (vertical) {
        if (pos < -100 || pos > size.height + 100) continue;
      } else {
        if (pos < -100 || pos > size.width + 100) continue;
      }
      final label = unit.label(
        DateTime.fromMillisecondsSinceEpoch(t.toInt(), isUtc: true),
      );
      _active.add(_get().set(t, pos, true, label, 16));
      diagnostics!.numMajor++;
    }
    diagnostics!
      ..majorPx = unit.majorMs * scale
      ..minorPx = unit.minorMs * scale;
    return _active;
  }

  void renderGrid(Canvas canvas, double zoom, double pan, Size size,
      {bool vertical = false}) {
    final scale = _basePxPerMs * zoom;
    final leftMs = -pan / scale;
    final mainExtent = vertical ? size.height : size.width;
    final rightMs = leftMs + mainExtent / scale;
    final unit = _pickUnit(scale);
    double ceilTo(double v, double step) {
      final m = v % step;
      return m == 0 ? v : v + (step - m);
    }

    final firstMajor = ceilTo(leftMs, unit.majorMs);
    for (double t = firstMajor; t <= rightMs; t += unit.majorMs) {
      final pos = (t - leftMs) * scale;
      if (!vertical) {
        if (pos >= -10 && pos <= size.width + 10) {
          canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), _grid);
        }
      } else {
        if (pos >= -10 && pos <= size.height + 10) {
          canvas.drawLine(Offset(0, pos), Offset(size.width, pos), _grid);
        }
      }
    }
  }

  void renderTicks({
    required Canvas canvas,
    required List<_PkgTick> ticks,
    required double centerY,
    required Size size,
    int labelStride = 1,
    Map<TimeScaleLOD, TextStyle>? styleByLOD,
    TextStyle? baseLabelStyle,
    String? fontFamilyOverride,
    bool vertical = false,
    TickShapePainter? customPainter,
    Offset tickOffset = Offset.zero,
    double tickScale = 1.0,
  }) {
    int majorIndex = 0;
    for (final tick in ticks) {
      if (customPainter != null) {
        final info = TickInfo(
          positionMainAxis: tick.x,
          centerCrossAxis: centerY,
          height: tick.h,
          isMajor: tick.isMajor,
          label: tick.label,
          vertical: vertical,
        );
        final ctx = TickDrawContext(
          size: size,
          axisColor: _major.color,
          minorColor: _minor.color,
          tickOffset: tickOffset,
          tickScale: tickScale,
        );
        customPainter(canvas, info, ctx);
      } else {
        final p = tick.isMajor ? _major : _minor;
        final double scaledH = tick.h * tickScale;
        if (!vertical) {
          canvas.drawLine(
            Offset(tick.x + tickOffset.dx, centerY - scaledH + tickOffset.dy),
            Offset(tick.x + tickOffset.dx, centerY + scaledH + tickOffset.dy),
            p,
          );
        } else {
          canvas.drawLine(
            Offset(centerY - scaledH + tickOffset.dx, tick.x + tickOffset.dy),
            Offset(centerY + scaledH + tickOffset.dx, tick.x + tickOffset.dy),
            p,
          );
        }
      }
      if (tick.isMajor && tick.label.isNotEmpty) {
        if (labelStride > 1 && (majorIndex++ % labelStride != 0)) {
          diagnostics?.labelsDroppedByStride++;
          continue;
        }
        TextStyle style = baseLabelStyle ??
            TextStyle(
              color: _labelColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            );
        if (style.color == null) {
          style = style.merge(TextStyle(color: _labelColor));
        }
        if (styleByLOD != null) {
          final lod = _inferLODFromLabel(tick.label);
          final baseForAll = styleByLOD[TimeScaleLOD.all];
          if (baseForAll != null) style = style.merge(baseForAll);
          final specific = styleByLOD[lod];
          if (specific != null) style = style.merge(specific);
        }
        if (fontFamilyOverride != null && fontFamilyOverride.isNotEmpty) {
          style = style.merge(TextStyle(fontFamily: fontFamilyOverride));
        }
        final tp = _tp('${tick.label}_${_labelColor.toARGB32()}_12_5', style);
        tp.layout();
        if (!vertical) {
          final tx = tick.x + tickOffset.dx - tp.width / 2;
          if (tx <= size.width && tx + tp.width >= 0) {
            tp.paint(canvas,
                Offset(tx, centerY + (tick.h * tickScale) + 4 + tickOffset.dy));
            diagnostics?.labelsPainted++;
          }
        } else {
          final ty = tick.x + tickOffset.dy - tp.height / 2;
          final double labelX =
              centerY + (tick.h * tickScale) + 4 + tickOffset.dx;
          if (ty <= size.height && ty + tp.height >= 0) {
            tp.paint(canvas, Offset(labelX, ty));
            diagnostics?.labelsPainted++;
          }
        }
      }
    }
  }

  TimeScaleLOD _inferLODFromLabel(String label) {
    if (label.endsWith(':00')) return TimeScaleLOD.hour;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(label)) return TimeScaleLOD.day;
    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(label)) return TimeScaleLOD.month;
    if (RegExp(r'^\d{4}$').hasMatch(label)) return TimeScaleLOD.year;
    if (label.endsWith('0s')) return TimeScaleLOD.decade;
    if (label.endsWith('00s')) return TimeScaleLOD.century;
    return TimeScaleLOD.millennium;
  }

  TextPainter _tp(String key, TextStyle s) {
    if (!_tpCache.containsKey(key)) {
      _tpCache[key] = TextPainter(
        text: TextSpan(text: key.split('_').first, style: s),
        textDirection: TextDirection.ltr,
      );
    } else {
      _tpCache[key]!.text = TextSpan(text: key.split('_').first, style: s);
    }
    return _tpCache[key]!;
  }

  _PkgTick _get() => _pool.isNotEmpty ? _pool.removeLast() : _PkgTick();

  _PkgUnit _pickUnit(double pxPerMs) {
    const targetPx = 90.0;
    _PkgUnit mk(
      double maj,
      double min,
      String Function(DateTime) fmt,
      TimeScaleLOD lod,
    ) =>
        _PkgUnit(maj, min, fmt, lod);
    final hour = 3600e3,
        day = 24 * 3600e3,
        week = 7 * day,
        month = 30 * day,
        year = 365 * day,
        dec = 10 * year,
        cen = 100 * year,
        mil = 1000 * year;
    final cand = <_PkgUnit>[
      mk(
        hour,
        hour / 6,
        (d) => '${d.hour.toString().padLeft(2, '0')}:00',
        TimeScaleLOD.hour,
      ),
      mk(
        day,
        hour,
        (d) =>
            '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        TimeScaleLOD.day,
      ),
      mk(
        week,
        day,
        (d) =>
            'W${(((DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(d.year, 1, 1)).inDays) / 7).floor() + 1)}',
        TimeScaleLOD.week,
      ),
      mk(
        month,
        week,
        (d) => '${d.year}-${d.month.toString().padLeft(2, '0')}',
        TimeScaleLOD.month,
      ),
      mk(year, month, (d) => '${d.year}', TimeScaleLOD.year),
      mk(dec, year, (d) => '${(d.year ~/ 10) * 10}s', TimeScaleLOD.decade),
      mk(cen, dec, (d) => '${(d.year ~/ 100) * 100}s', TimeScaleLOD.century),
      mk(
        mil,
        cen,
        (d) => '${(d.year ~/ 1000) * 1000}',
        TimeScaleLOD.millennium,
      ),
    ];
    for (final u in cand) {
      if (pxPerMs * u.majorMs >= targetPx) return u;
    }
    return cand.first;
  }
}

class _PkgTick {
  late double tMs, x, h;
  late bool isMajor;
  late String label;
  _PkgTick set(double t, double xx, bool maj, String lbl, double hh) {
    tMs = t;
    x = xx;
    isMajor = maj;
    label = lbl;
    h = hh;
    return this;
  }
}

class _PkgUnit {
  final double majorMs, minorMs;
  final String Function(DateTime) label;
  final TimeScaleLOD lod;
  _PkgUnit(this.majorMs, this.minorMs, this.label, this.lod);
}

class _Diagnostics {
  final TimeScaleLOD lod;
  final double pxPerMs;
  final double targetPx;
  final double majorMs;
  final double minorMs;
  int numMajor = 0;
  int numMinor = 0;
  int labelsPainted = 0;
  int labelsDroppedByStride = 0;
  double majorPx = 0;
  double minorPx = 0;
  _Diagnostics({
    required this.lod,
    required this.pxPerMs,
    required this.targetPx,
    required this.majorMs,
    required this.minorMs,
  });
}

class _EventLayout {
  final TimelineEvent event;
  final double axisCenterCross;
  final Offset baseOffset;
  final double localScale;
  bool hasSpan;
  double spanStartClamped;
  double spanEndClamped;
  bool stickyClamped;
  double markerMain = 0;
  late Offset markerPosition;
  int stackIndex = 0;
  int stackCount = 1;
  double markerScale = 1.0;
  double opacity = 1.0;
  int spanStackIndex = 0;
  double spanOpacity = 1.0;
  _EventLayout({
    required this.event,
    required this.markerMain,
    required this.axisCenterCross,
    required this.baseOffset,
    required this.localScale,
    required this.hasSpan,
    required this.spanStartClamped,
    required this.spanEndClamped,
    required this.stickyClamped,
  });
}

class _SpanInterval {
  final double start;
  final double end;
  final int importance;
  final _EventLayout layout;
  _SpanInterval({
    required this.start,
    required this.end,
    required this.importance,
    required this.layout,
  });
}