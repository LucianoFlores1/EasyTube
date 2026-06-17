import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../extractor/application/extractor_service.dart';
import '../../extractor/presentation/extractor_sheet.dart';
import '../application/browser_notifier.dart';
import 'download_fab.dart';

class BrowserPage extends ConsumerStatefulWidget {
  const BrowserPage({super.key});

  @override
  ConsumerState<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends ConsumerState<BrowserPage> {
  late final WebViewController _controller;
  late final TextEditingController _urlField;
  Timer? _prefetchTimer;

  @override
  void initState() {
    super.initState();
    _urlField = TextEditingController();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => ref.read(browserProvider.notifier).setProgress(p),
          onPageStarted: (url) {
            ref.read(browserProvider.notifier)
              ..setLoading(true)
              ..onUrlChanged(url);
            _syncUrlField(url);
          },
          onPageFinished: (url) async {
            ref.read(browserProvider.notifier).setLoading(false);
            await _refreshChrome(url);
          },
          onUrlChange: (change) async {
            final url = change.url ?? '';
            ref.read(browserProvider.notifier).onUrlChanged(url);
            _syncUrlField(url);
            await _refreshChrome(url);
          },
          onNavigationRequest: (request) {
            final host = Uri.tryParse(request.url)?.host ?? '';
            final blocked = AppConstants.blockedHosts
                .any((h) => host == h || host.endsWith('.$h'));
            return blocked
                ? NavigationDecision.prevent
                : NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(AppConstants.youtubeHomeUrl));
    ref.read(browserProvider.notifier).controller = _controller;
  }

  Future<void> _refreshChrome(String url) async {
    final back = await _controller.canGoBack();
    final forward = await _controller.canGoForward();
    final title = await _controller.getTitle();
    if (!mounted) return;
    final notifier = ref.read(browserProvider.notifier)
      ..setNavState(canGoBack: back, canGoForward: forward);
    if (title != null) notifier.setTitle(title);
  }

  void _syncUrlField(String url) {
    if (_urlField.text != url) _urlField.text = url;
  }

  void _submitUrl(String value) {
    var input = value.trim();
    if (input.isEmpty) return;
    if (!input.startsWith('http://') && !input.startsWith('https://')) {
      // Treat plain text as a YouTube search.
      input = input.contains('.') && !input.contains(' ')
          ? 'https://$input'
          : 'https://m.youtube.com/results?search_query=${Uri.encodeQueryComponent(input)}';
    }
    _controller.loadRequest(Uri.parse(input));
  }

  void _openExtractor(String videoId, String? playlistId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExtractorSheet(videoId: videoId, playlistId: playlistId),
    );
  }

  @override
  void dispose() {
    _prefetchTimer?.cancel();
    _urlField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(browserProvider);

    // Pre-warm the extractor once a video has been on screen ~1.2s, so the
    // download sheet shows formats instantly. Debounced to avoid hammering
    // YouTube while scrubbing through autoplay/radio.
    ref.listen(browserProvider.select((s) => s.currentVideoId), (_, id) {
      _prefetchTimer?.cancel();
      if (id == null) return;
      _prefetchTimer = Timer(const Duration(milliseconds: 1200), () {
        ref.read(extractOptionsProvider(id));
      });
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: _UrlBar(controller: _urlField, onSubmitted: _submitUrl),
        actions: [
          IconButton(
            tooltip: 'Atrás',
            onPressed: state.canGoBack ? () => _controller.goBack() : null,
            icon: const Icon(Icons.arrow_back),
          ),
          IconButton(
            tooltip: 'Adelante',
            onPressed:
                state.canGoForward ? () => _controller.goForward() : null,
            icon: const Icon(Icons.arrow_forward),
          ),
          IconButton(
            tooltip: state.isLoading ? 'Detener' : 'Recargar',
            onPressed: () => state.isLoading
                ? _controller.reload()
                : _controller.reload(),
            icon: Icon(state.isLoading ? Icons.close : Icons.refresh),
          ),
        ],
        bottom: state.isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: state.progress == 0 ? null : state.progress,
                  minHeight: 2,
                ),
              )
            : null,
      ),
      // Claim vertical drags so the page scrolls inside the horizontal
      // PageView (tab swiper); horizontal drags still switch tabs.
      body: WebViewWidget(
        controller: _controller,
        gestureRecognizers: const {
          Factory<VerticalDragGestureRecognizer>(
              VerticalDragGestureRecognizer.new),
        },
      ),
      floatingActionButton: DownloadFab(
        visible: state.hasVideo,
        onPressed: () =>
            _openExtractor(state.currentVideoId!, state.playlistId),
      ),
    );
  }
}

class _UrlBar extends StatelessWidget {
  const _UrlBar({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.go,
        keyboardType: TextInputType.url,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceVariant,
          hintText: 'Buscar o ingresar URL',
          prefixIcon: const Icon(Icons.search, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
