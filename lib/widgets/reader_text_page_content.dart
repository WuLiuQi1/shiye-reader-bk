import 'package:flutter/material.dart';

import '../core/reader/native_text_paginator.dart';
import '../core/reader/reader_text_layout.dart';
import '../core/reader/reader_text_pagination.dart';

/// Shared final renderer for local and online flowing-text pages.
///
/// It consumes the same [ReaderTextPage] and [NativeTextFlowStyle] used during
/// pagination so measurement and painting cannot silently drift apart.
class ReaderTextPageContent extends StatelessWidget {
  const ReaderTextPageContent({
    super.key,
    required this.page,
    required this.chapterTitle,
    required this.bodyStyle,
    required this.flowStyle,
    this.sourceSpanBuilder,
  });

  final ReaderTextPage page;
  final String chapterTitle;
  final TextStyle bodyStyle;
  final NativeTextFlowStyle flowStyle;
  final ReaderSourceSpanBuilder? sourceSpanBuilder;

  @override
  Widget build(BuildContext context) {
    final body = RichText(
      text: page.buildSpan(
        style: bodyStyle,
        sourceSpanBuilder: sourceSpanBuilder,
      ),
      selectionRegistrar: SelectionContainer.maybeOf(context),
      selectionColor:
          DefaultSelectionStyle.of(context).selectionColor ??
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
      textAlign: flowStyle.textAlign,
      textDirection: flowStyle.textDirection,
      textScaler: flowStyle.textScaler,
      locale: flowStyle.locale,
      strutStyle: flowStyle.strutStyle,
      textWidthBasis: flowStyle.textWidthBasis,
      textHeightBehavior: flowStyle.textHeightBehavior,
    );
    if (!page.showsChapterTitle || chapterTitle.trim().isEmpty) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          chapterTitle.trim(),
          textAlign: TextAlign.left,
          style: bodyStyle.copyWith(
            fontSize: ((bodyStyle.fontSize ?? 19) * 1.28).clamp(22, 28),
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        SizedBox(height: (bodyStyle.fontSize ?? 19) * 1.15),
        Expanded(child: body),
      ],
    );
  }
}
