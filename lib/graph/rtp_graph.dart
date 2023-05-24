import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter/rendering.dart';

typedef GraphItemBuilder = Widget Function(Offset point);

class GraphData {
  final Offset offset;
  final Color color;
  const GraphData({
    this.color = Colors.green,
    required this.offset,
  });
}

class RTPGraph extends StatelessWidget {
  final GraphRenderDelegate graphRenderDelegate;
  final List<GraphData> points;
  final GraphItemBuilder? labelItemBuilder;
  const RTPGraph({
    super.key,
    this.labelItemBuilder,
    required this.points,
    this.graphRenderDelegate = const DefaultRTPGraphRenderDelegate(),
  });

  @override
  Widget build(BuildContext context) {
    return Graph(
      points: points,
      graphRenderDelegate: graphRenderDelegate,
      pointPaint: Paint()
        ..color = Colors.green
        ..strokeWidth = 2.0,
      basePaint: Paint()
        ..color = const Color(0xff4b4b4b)
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
      children: List.generate(
        points.length,
        (index) => GraphLabel(
          points[index].offset,
          child: labelItemBuilder?.call(points[index].offset) ??
              Text('${points[index].offset.dx}'),
        ),
      ),
    );
  }
}

class Graph extends MultiChildRenderObjectWidget {
  final GraphRenderDelegate graphRenderDelegate;
  final List<GraphData> points;
  final Offset baseMargin;
  final Offset pointsMargin;
  final Paint pointPaint;
  final Paint basePaint;
  const Graph({
    required this.pointPaint,
    required this.basePaint,
    this.pointsMargin = const Offset(.1, .15),
    this.baseMargin = const Offset(.1, .1),
    required this.points,
    required this.graphRenderDelegate,
    super.key,
    super.children,
  });

  @override
  RenderGraph createRenderObject(BuildContext context) => RenderGraph(
        graphRenderDelegate: graphRenderDelegate,
        points: points,
        baseMargin: baseMargin,
        pointsMargin: pointsMargin,
        pointPaint: pointPaint,
        basePaint: basePaint,
      );
}

abstract class BaseRenderGraph extends RenderBox {
  final GraphRenderDelegate graphRenderDelegate;
  final List<GraphData> points;
  final Offset? baseMargin;
  final Offset? pointsMargin;
  final Paint basePaint;
  final Paint pointPaint;
  BaseRenderGraph({
    required this.pointPaint,
    required this.basePaint,
    this.baseMargin,
    this.pointsMargin,
    required this.points,
    required this.graphRenderDelegate,
  });
}

class RenderGraph extends BaseRenderGraph
    with
        ContainerRenderObjectMixin<RenderBox, GraphParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, GraphParentData>,
        GraphRenderManager {
  late DragGestureRecognizer _drag;

  RenderGraph({
    required super.pointPaint,
    required super.basePaint,
    super.baseMargin,
    super.pointsMargin,
    required super.graphRenderDelegate,
    required super.points,
  }) {
    _drag = HorizontalDragGestureRecognizer()
      ..onStart = (DragStartDetails details) {
        _updatePointerPosition(details.localPosition);
      }
      ..onUpdate = (DragUpdateDetails details) {
        _updatePointerPosition(details.localPosition);
      }
      ..onEnd = (details) {
        _resetPointer();
      };
  }

  @override
  void setupParentData(covariant RenderObject child) {
    child.parentData = GraphParentData();
  }

  @override
  void performLayout() {
    size = constraints.constrain(Size.square(constraints.biggest.shortestSide));
    double xm = baseMargin != null ? baseMargin!.dx : 1.0;
    double ym = baseMargin != null ? baseMargin!.dy : 1.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      constraints.enforce(
        constraints.copyWith(
          minWidth: size.shortestSide * xm / 2,
          minHeight: size.shortestSide * ym / 2,
          maxWidth: size.shortestSide * xm,
          maxHeight: size.shortestSide * ym,
        ),
      );
      child.layout(constraints);
    }
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    if (event is PointerDownEvent) {
      _drag.addPointer(event);
    }
  }

  void _updatePointerPosition(Offset localPosition) {
    double dx = localPosition.dx.clamp(0, size.width);
    double dy = localPosition.dy.clamp(0, size.height);
    pointer = Offset(dx, dy);

    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _resetPointer() {
    pointer = Offset.zero;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void detach() {
    _drag.dispose();
    super.detach();
  }

  @override
  String toStringShort() {
    return graphRenderDelegate.debug(points.map((e) => e.offset.dx).toList());
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = context.canvas;

    c.save();
    c.translate(offset.dx, offset.dy);
    drawBase(
      c,
      margin: baseMargin ?? const Offset(.1, .1),
    );

    final hits = drawPoints(
      c,
      margin: pointsMargin ??
          const Offset(
            10,
            10,
          ),
      points: points,
    );

    for (var child = firstChild; child != null; child = childAfter(child)) {
      drawLabel(
        child,
        hits,
        context,
      );
    }

    c.restore();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return false;
  }
}

abstract class GraphRenderDelegate {
  const GraphRenderDelegate();

  String debug(List<double> points);
  Offset absoluteMargin(
    Offset margin,
    Size size,
  );
  List<Offset> axisPoints(
    bool isX,
    Offset margin,
    Size size,
  );
  void drawLabel(
    RenderObject renderObject,
    PaintingContext context,
    Offset offset,
    Size size,
  );
  Map<Offset, Offset> drawPoints(
    Canvas canvas,
    Paint paint,
    List<GraphData> points, {
    required Offset pointer,
    required Offset margin,
    required Size size,
  });
  void drawBase(
    Canvas canvas,
    Paint paint, {
    required Offset margin,
    required Size size,
  });
}

class DefaultRTPGraphRenderDelegate extends GraphRenderDelegate {
  const DefaultRTPGraphRenderDelegate();
  @override
  void drawBase(
    Canvas canvas,
    Paint paint, {
    required Offset margin,
    required Size size,
  }) {
    final x = axisPoints(
      true,
      margin,
      size,
    );
    final y = axisPoints(
      false,
      margin,
      size,
    );
    canvas.drawLine(x.first, x.last, paint);
    canvas.drawLine(y.first, y.last, paint);
  }

  @override
  Map<Offset, Offset> drawPoints(
    Canvas canvas,
    Paint paint,
    List<GraphData> points, {
    required Offset pointer,
    required Offset margin,
    required Size size,
  }) {
    final xAxis = axisPoints(true, margin, size);
    final yAxis = axisPoints(false, margin, size);
    final Map<Offset, Offset> markedForLabel = {};
    final yMax = yAxis.last;
    final yMin = yAxis.first;
    final xMax = xAxis.last;
    final xMin = xAxis.first;

    var m = absoluteMargin(margin, size);
    Set<Color> colors = points.map((e) => e.color).toSet();
    for (var color in colors) {
      var cp = points.where((element) => element.color == color).toList();
      final px = cp.map((e) => e.offset.dx).toList();
      final py = cp.map((e) => e.offset.dy).toList();

      final yy = plotPercentages(px, (xMax.dy - m.dy) - (xMin.dy), margin: margin);
      final xx = plotPercentages(py, yMax.dx - yMin.dx, );

      Offset? previousPoint;
      for (int i = 0; i < cp.length; i++) {
        var r = 3.5;//m.dx/3;
        Rect rect = Rect.fromCircle(
          center: Offset(
            xx[i],
            yy[i],
          ),
          radius: r,
        );
        if (previousPoint != null) {
          canvas.drawLine(
            previousPoint,
            rect.center,
            paint..color = cp[i].color,
          );
        }
        previousPoint = rect.center;
        if (hitTest(rect, pointer, cp[i].offset, markedForLabel)) {
          canvas.drawCircle(
            Offset(
              xx[i],
              yy[i],
            ),
            r * 1.5,
            paint..color = cp[i].color.withOpacity(.5),
          );
        }
        canvas.drawCircle(
          Offset(
            xx[i],
            yy[i],
          ),
          r,
          paint..color = cp[i].color,
        );
      }
    }

    return markedForLabel;
  }

  bool hitTest(
    Rect rect,
    Offset pointer,
    Offset point,
    Map<Offset, Offset> markedForLabel,
  ) {
    bool hit = rect.contains(pointer);
    if (hit) {
      markedForLabel.putIfAbsent(
        point,
        () => rect.center,
      );
    }
    return hit;
  }

  List<double> plotPercentages(List<double> percentages, double axisExtent,
      {Offset? margin}) {
    final double maxPercentage = percentages
        .reduce((value, element) => value > element ? value : element);
    final List<double> normalized = [];
    for (int i = 0; i < percentages.length; i++) {
      final double percentage = percentages[i];
      final double filledBars = margin != null
          ? (axisExtent + (axisExtent * margin.dy)) -
              (percentage * axisExtent / maxPercentage)
          : (percentage * axisExtent / maxPercentage);
      normalized.add(filledBars);
    }
    return normalized;
  }

  @override
  String debug(
    List<double> points,
  ) {
    const double axisExtent = 30;
    StringBuffer buffer = StringBuffer();
    final double maxPercentage =
        points.reduce((value, element) => value > element ? value : element);
    for (int i = 0; i < points.length; i++) {
      final double percentage = points[i];
      final double filledBars = (percentage * axisExtent / maxPercentage);

      final int emptyBars = (axisExtent - filledBars).toInt();

      final String bar = '|' * filledBars.toInt() + ' ' * emptyBars;
      final String percentageString = percentage.toStringAsFixed(2);
      buffer.writeln('Bar ${i + 1}: $bar  $percentageString%');
    }
    return buffer.toString();
  }

  @override
  Offset absoluteMargin(Offset margin, Size size) => Offset(
        size.shortestSide * margin.dx,
        size.shortestSide * margin.dy,
      );

  @override
  List<Offset> axisPoints(
    bool isX,
    Offset margin,
    Size size,
  ) {
    final absMargin = absoluteMargin(
      margin,
      size,
    );
    final rect = Rect.fromPoints(
        size.topLeft(Offset.zero), size.bottomRight(Offset.zero));
    return isX
        ? [
            rect.topLeft + absMargin,
            rect.bottomLeft.translate(absMargin.dx, -absMargin.dy)
          ]
        : [
            rect.bottomLeft.translate(
              absMargin.dx,
              -absMargin.dy,
            ),
            rect.bottomRight.translate(-absMargin.dx, -absMargin.dy)
          ];
  }

  @override
  void drawLabel(
    RenderObject renderObject,
    PaintingContext context,
    Offset offset,
    Size size,
  ) {
    Offset o = Offset(
        size.width / 2 > offset.dx
            ? offset.dx + size.shortestSide * .1
            : offset.dx - (size.shortestSide * .1) * 2,
        offset.dy - size.shortestSide * .1);

    renderObject.paint(context, o);
  }
}

mixin GraphRenderManager on BaseRenderGraph {
  Offset pointer = Offset.zero;

  void drawBase(Canvas canvas, {Offset margin = const Offset(1, 1)}) {
    graphRenderDelegate.drawBase(
      canvas,
      super.basePaint,
      margin: margin,
      size: size,
    );
  }

  Map<Offset, Offset> drawPoints(
    Canvas canvas, {
    List<GraphData> points = const [],
    required Offset margin,
  }) {
    return graphRenderDelegate.drawPoints(
      canvas,
      super.pointPaint,
      points,
      pointer: pointer,
      margin: margin,
      size: size,
    );
  }

  void drawLabel(
    RenderObject child,
    Map<Offset, Offset> hits,
    PaintingContext context,
  ) {
    final pd = (child.parentData as GraphParentData).point;
    if (hits.containsKey(pd)) {
      graphRenderDelegate.drawLabel(
        child,
        context,
        hits[pd]!,
        size,
      );
    }
  }
}

class GraphLabel extends ParentDataWidget<GraphParentData> {
  final Offset data;
  const GraphLabel(
    this.data, {
    super.key,
    required super.child,
  });

  @override
  void applyParentData(RenderObject renderObject) {
    if (renderObject.parentData is! GraphParentData) {
      renderObject.parentData = GraphParentData();
    }

    final pd = renderObject.parentData as GraphParentData;
    if (pd.point != data) {
      pd.point = data;
      final RenderGraph targetParent = renderObject.parent! as RenderGraph;
      targetParent.markNeedsPaint();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => Graph;
}

class GraphParentData extends ContainerBoxParentData<RenderBox> {
  Offset point = Offset.zero;
}
