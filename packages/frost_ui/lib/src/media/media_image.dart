import 'package:flutter/widgets.dart';

import '../primitives/_media_image_registry.dart';
import '../surface/_window_background.dart';

/// Marks an actually displayed image inside a [FrostMediaCard] or a
/// [FrostMediaFrame]. Provider-mode FrostMediaFrame supplies this automatically.
/// Custom image loaders wrap only their decoded Image.frameBuilder branch, never
/// loading, error, unsupported content, or recovery controls. No pixels or
/// loading state are owned here. Outside a card or frame this wrapper has no
/// visual effect of its own; under an ambient host, glass chrome above it
/// takes its black/white-safe fill.
class FrostMediaImage extends StatefulWidget {
  const FrostMediaImage({required this.child, super.key});
  final Widget child;
  @override
  State<FrostMediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<FrostMediaImage> with FrostMediaImageClaim {
  @override
  Widget build(BuildContext context) => FrostAmbientMediaRegistration(child: widget.child);
}
