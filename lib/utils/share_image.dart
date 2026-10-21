import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Shows a preview dialog of [widget] and lets the user share it as a PNG image.
/// Output is always 1080x1080 for Instagram/Facebook compatibility.
Future<void> shareWidgetAsImage({
  required BuildContext context,
  required Widget widget,
  required String fileName,
  String? caption,
}) async {
  final key = GlobalKey();
  final theme = Theme.of(context);
  await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final bottomPadding = MediaQuery.of(ctx).viewPadding.bottom;
      return Dialog(
        backgroundColor: const Color(0xFF0B211A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: RepaintBoundary(
                      key: key,
                      child: SizedBox(
                        width: 360,
                        child: widget,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                      ),
                      onPressed: () async {
                        try {
                          final boundary = key.currentContext?.findRenderObject()
                              as RenderRepaintBoundary?;
                          if (boundary == null) {
                            if (ctx.mounted) Navigator.pop(ctx, false);
                            return;
                          }
                          final ratio = (1080 / 360).clamp(2.0, 4.0);
                          final image = await boundary.toImage(pixelRatio: ratio);
                          final byteData =
                              await image.toByteData(format: ui.ImageByteFormat.png);
                          if (byteData == null) {
                            if (ctx.mounted) Navigator.pop(ctx, false);
                            return;
                          }
                          final dir = await getTemporaryDirectory();
                          final file = File(
                              '${dir.path}${Platform.pathSeparator}$fileName.png');
                          await file.writeAsBytes(byteData.buffer.asUint8List());
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx, true);
                          await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: caption ?? 'SAJDA: DAILY ATHAN & QIBLA'));
                        } catch (_) {
                          if (ctx.mounted) Navigator.pop(ctx, false);
                        }
                      },
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Share Image'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

