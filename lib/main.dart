import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'app_state.dart';
import 'haptics.dart';
import 'ocr_service.dart';

/// გაზიარებული ლინკი — აპის მისამართი.
const String kShareLink = 'https://text.qgis.ge/';

/// შიფრტექსტის QR-ის მაქსიმალური სიგრძე (QR-ის ტევადობის ლიმიტი).
const int kMaxQrChars = 1200;

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const CryptoNoteApp(),
    ),
  );
}

class CryptoNoteApp extends StatelessWidget {
  const CryptoNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3F51B5);
    return MaterialApp(
      title: 'დაშიფრული ჩანაწერი',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _textController = TextEditingController();
  final _pinController = TextEditingController();
  bool _pinVisible = false;
  double _resultScale = 1.0;
  bool _scanning = false;

  @override
  void dispose() {
    _textController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _run() {
    FocusScope.of(context).unfocus(); // კლავიატურის დახურვა შედეგის სანახავად
    context.read<AppState>().run(_textController.text, _pinController.text);
  }

  Future<void> _scan() async {
    FocusScope.of(context).unfocus();
    final bool encryptMode = context.read<AppState>().mode == Mode.encrypt;
    setState(() => _scanning = true);
    try {
      // დაშიფვრისას ქართული+ლათინური (kat+eng), განშიფვრისას Base32 (eng).
      final text = await scanTextFromCamera(georgian: encryptMode);
      if (!mounted) return;
      if (text == null) return; // გაუქმდა
      if (text.isEmpty) {
        _snack(context, 'ტექსტი ვერ ამოვიცანი — სცადე უკეთესი განათება/ფოკუსი');
        return;
      }
      setState(() => _textController.text = text);
      hapticTick();
    } catch (_) {
      if (mounted) _snack(context, 'სკანირება ვერ მოხერხდა');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isEncrypt = state.mode == Mode.encrypt;

    return Scaffold(
      appBar: AppBar(
        title: const Text('დაშიფრული ჩანაწერი'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'აპის გაზიარება',
            onPressed: () => _showShareLinkDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // რეჟიმის გადამრთველი
                  SegmentedButton<Mode>(
                    segments: const [
                      ButtonSegment(
                        value: Mode.encrypt,
                        label: Text('დაშიფვრა'),
                        icon: Icon(Icons.lock_outline),
                      ),
                      ButtonSegment(
                        value: Mode.decrypt,
                        label: Text('განშიფვრა'),
                        icon: Icon(Icons.lock_open_outlined),
                      ),
                    ],
                    selected: {state.mode},
                    onSelectionChanged: (s) =>
                        context.read<AppState>().setMode(s.first),
                  ),
                  const SizedBox(height: 20),

                  // ტექსტის ველი
                  TextField(
                    controller: _textController,
                    minLines: 4,
                    maxLines: 8,
                    // განშიფვრისას კლავიატურამ შიფრტექსტი არ უნდა „გაასწოროს"
                    autocorrect: isEncrypt,
                    enableSuggestions: isEncrypt,
                    textCapitalization: isEncrypt
                        ? TextCapitalization.sentences
                        : TextCapitalization.none,
                    style: isEncrypt
                        ? null
                        : const TextStyle(
                            fontFamily: 'monospace', letterSpacing: 1),
                    decoration: InputDecoration(
                      labelText:
                          isEncrypt ? 'ტექსტი დასაშიფრად' : 'დაშიფრული ტექსტი',
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  // კამერით სკანირება (მხოლოდ native პლატფორმებზე)
                  if (kOcrSupported) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: (state.busy || _scanning) ? null : _scan,
                        icon: _scanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.document_scanner_outlined,
                                size: 20),
                        label: Text(_scanning
                            ? 'ვასკანერებ…'
                            : 'კამერით სკანირება'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // PIN-ის ველი
                  TextField(
                    controller: _pinController,
                    obscureText: !_pinVisible,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: null, // password manager-ს არ ვთავაზობთ
                    decoration: InputDecoration(
                      labelText: 'PIN (საერთო კოდი)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_pinVisible
                            ? Icons.visibility_off
                            : Icons.visibility),
                        tooltip: _pinVisible ? 'დამალვა' : 'ჩვენება',
                        onPressed: () =>
                            setState(() => _pinVisible = !_pinVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // მთავარი ღილაკი
                  FilledButton.icon(
                    onPressed: state.busy ? null : _run,
                    icon: state.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(isEncrypt
                            ? Icons.lock_outline
                            : Icons.lock_open_outlined),
                    label: Text(
                      isEncrypt ? 'დაშიფვრა' : 'განშიფვრა',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),

                  // შეცდომა
                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.error!,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // შედეგი
                  if (state.result.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text(
                          'შედეგი',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        // ტექსტის ზომის რეგულირება — ხელით გადასაწერად
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'პატარა ტექსტი',
                          icon: const Icon(Icons.text_decrease),
                          onPressed: _resultScale <= 0.8
                              ? null
                              : () => setState(
                                  () => _resultScale -= 0.15),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'დიდი ტექსტი',
                          icon: const Icon(Icons.text_increase),
                          onPressed: _resultScale >= 2.0
                              ? null
                              : () => setState(
                                  () => _resultScale += 0.15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ResultBlock(
                      text: state.result,
                      monospace: isEncrypt,
                      scale: _resultScale,
                      showResultQr: isEncrypt &&
                          state.result.replaceAll(' ', '').length <=
                              kMaxQrChars,
                    ),
                  ],

                  const SizedBox(height: 32),
                  Text(
                    'AES-GCM 256 · PBKDF2 · ერთი PIN ორ ადამიანს შორის',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showShareLinkDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('გააზიარე აპი'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'დაასკანერე QR ან გაუზიარე ლინკი მეორე ადამიანს.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            _QrCard(data: kShareLink, size: 200),
            const SizedBox(height: 16),
            SelectableText(
              kShareLink,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('გაზიარება'),
            onPressed: () {
              hapticTick();
              SharePlus.instance.share(
                ShareParams(
                  text: kShareLink,
                  subject: 'დაშიფრული ჩანაწერი',
                ),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('ლინკის კოპირება'),
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: kShareLink));
              hapticTick();
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                _snack(context, 'ლინკი დაკოპირდა');
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('დახურვა'),
          ),
        ],
      ),
    );
  }
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
  );
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.data, this.size = 200});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size,
        backgroundColor: Colors.white,
        errorStateBuilder: (ctx, err) => SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: Text(
              'ტექსტი QR-ისთვის ძალიან გრძელია',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultBlock extends StatelessWidget {
  const _ResultBlock({
    required this.text,
    required this.monospace,
    required this.scale,
    required this.showResultQr,
  });

  final String text;
  final bool monospace;
  final double scale;
  final bool showResultQr;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(
            text,
            style: TextStyle(
              fontFamily: monospace ? 'monospace' : null,
              fontSize: (monospace ? 20 : 16) * scale,
              height: 1.6,
              fontWeight: monospace ? FontWeight.w600 : null,
              letterSpacing: monospace ? 2 : null,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              if (showResultQr)
                OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: const Text('QR'),
                  onPressed: () => _showResultQr(context),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('გაზიარება'),
                onPressed: () {
                  hapticTick();
                  SharePlus.instance.share(ShareParams(text: text));
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('კოპირება'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  hapticTick();
                  if (context.mounted) _snack(context, 'დაკოპირდა');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showResultQr(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('შიფრტექსტის QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'მიმღებმა შეიძლება დაასკანეროს ხელით გადაწერის ნაცვლად.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            _QrCard(data: text.replaceAll(' ', ''), size: 240),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('დახურვა'),
          ),
        ],
      ),
    );
  }
}
