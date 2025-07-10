import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

class QuillEmbedMarker extends SingleChildRenderObjectWidget {
  const QuillEmbedMarker({Key? key, required Widget child}) : super(key: key, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) => QuillEmbedMarkerRenderBox();
}

class QuillEmbedMarkerRenderBox extends RenderProxyBox {} 