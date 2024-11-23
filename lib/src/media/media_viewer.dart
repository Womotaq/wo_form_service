import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wo_form/wo_form.dart';

class MediaViewer extends StatelessWidget {
  const MediaViewer({
    required this.media,
    this.fit,
    this.alignment = Alignment.center,
    this.package,
    super.key,
  });

  MediaViewer.url({
    required String url,
    this.fit,
    this.alignment = Alignment.center,
    this.package,
    super.key,
  }) : media = MediaUrl(url: url);

  final Media media;
  final BoxFit? fit;
  final Alignment alignment;

  /// Only used when media is MediaUrl & startsWith('assets/')
  final String? package;

  String _proxyRequestedURL(String url) => Uri(
        scheme: 'https',
        host: 'proxyrequestedurl-hpycyot3vq-ew.a.run.app',
        queryParameters: {'urlBase64': base64.encode(utf8.encode(url))},
      ).toString();

  Widget buildLoadingWidget(
    BuildContext context,
    Widget child,
    ImageChunkEvent? loadingProgress,
  ) =>
      loadingProgress == null
          ? child
          : Shimmer.fromColors(
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              highlightColor: Theme.of(context).colorScheme.surfaceContainerLow,
              child: child,
            );

  Widget buildErrorWidget({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    log('$title: $message');
    return const Icon(Icons.error);
  }

  @override
  Widget build(BuildContext context) {
    switch (media) {
      case MediaUrl(url: final url):
        if (url.startsWith('assets/')) {
          return Image.asset(
            url,
            package: package,
            fit: fit,
            alignment: alignment,
            errorBuilder: (context, error, stackTrace) => buildErrorWidget(
              context: context,
              title: 'Asset not found',
              message: url,
            ),
          );
        } else {
          return Image(
            image: CachedNetworkImageProvider(url),
            fit: fit,
            alignment: alignment,
            loadingBuilder: buildLoadingWidget,
            errorBuilder: (context, error, stackTrace) =>
                url.contains('womotaq-f.appspot.com')
                    ? buildErrorWidget(
                        context: context,
                        title: 'Image not found',
                        message: url,
                      )
                    // If image is not hosted on Firebase Storage,
                    // try to avoid CORS Policy
                    : Image(
                        image: CachedNetworkImageProvider(
                          _proxyRequestedURL(url),
                        ),
                        fit: fit,
                        alignment: alignment,
                        loadingBuilder: buildLoadingWidget,
                        errorBuilder: (context, error, stackTrace) =>
                            buildErrorWidget(
                          context: context,
                          title: 'Image not found',
                          message: url,
                        ),
                      ),
          );
        }
      case MediaFile(file: final file):
        if (kIsWeb) {
          return Image(
            image: CachedNetworkImageProvider(file.path),
            fit: fit,
            loadingBuilder: buildLoadingWidget,
            errorBuilder: (_, __, ___) => buildErrorWidget(
              context: context,
              title: 'File not found',
              message: file.path,
            ),
          );
        }
        return Image.file(
          File(file.path),
          fit: fit,
          alignment: alignment,
          errorBuilder: (context, error, stackTrace) => buildErrorWidget(
            context: context,
            title: 'File not found',
            message: file.path,
          ),
        );
    }
  }
}
