import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// How the user's uploaded photo is rendered as their avatar.
enum AvatarStyle {
  /// The photo as-is (square-cropped, resized) — full color.
  original,

  /// Black & white photographic (grayscale, no pixelation).
  noir,

  /// The app's own look: 1-bit black/white pixel art via Floyd–Steinberg
  /// dithering, matching the Lux & Nox mark.
  pixel,
}

class _AvatarJob {
  final Uint8List bytes;
  final AvatarStyle style;
  const _AvatarJob(this.bytes, this.style);
}

/// Square-crops, styles, and re-encodes an uploaded photo as a 256×256 PNG.
/// Runs in a background isolate on mobile/desktop ([compute]); on web it
/// executes inline, which is acceptable at these sizes because the source is
/// downscaled before the expensive filters run.
///
/// Returns null if [bytes] can't be decoded as an image.
Future<Uint8List?> processAvatar(Uint8List bytes, AvatarStyle style) {
  return compute(_process, _AvatarJob(bytes, style));
}

Uint8List? _process(_AvatarJob job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) return null;

  // Center-square first so every style starts from the same framing.
  final square = img.copyResizeCropSquare(decoded, size: 256);

  img.Image styled;
  switch (job.style) {
    case AvatarStyle.original:
      styled = square;
      break;
    case AvatarStyle.noir:
      styled = img.grayscale(square);
      break;
    case AvatarStyle.pixel:
      // Downsample to a coarse grid, force to pure black/white with
      // Floyd–Steinberg dithering, then upscale with nearest-neighbor so
      // each cell stays a hard-edged square pixel.
      final small = img.copyResize(
        img.grayscale(square),
        width: 48,
        height: 48,
        interpolation: img.Interpolation.average,
      );
      final dithered = img.ditherImage(
        small,
        quantizer: img.BinaryQuantizer(),
        kernel: img.DitherKernel.floydSteinberg,
      );
      styled = img.copyResize(
        dithered,
        width: 256,
        height: 256,
        interpolation: img.Interpolation.nearest,
      );
      break;
  }

  return Uint8List.fromList(img.encodePng(styled));
}
