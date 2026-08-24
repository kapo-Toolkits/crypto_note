import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'app_state.dart';

/// გაზიარებული ლინკი — აპის მისამართი.
const String kShareLink = 'https://text.qgis.ge/';

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
    return MaterialApp(
      title: 'დაშიფრული ჩანაწერი',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
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

  @override
  void dispose() {
    _textController.dispose();
    _pinController.dispose();
    super.dispose();
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
            tooltip: 'გაზიარება (QR)',
            onPressed: () => _showShareDialog(context),
          ),
        ],
      ),
      body: Center(
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
                  decoration: InputDecoration(
                    labelText: isEncrypt
                        ? 'ტექსტი დასაშიფრად'
                        : 'დაშიფრული ტექსტი',
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // PIN-ის ველი
                TextField(
                  controller: _pinController,
                  obscureText: !_pinVisible,
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
                  onPressed: state.busy
                      ? null
                      : () => context.read<AppState>().run(
                            _textController.text,
                            _pinController.text,
                          ),
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
                            color:
                                Theme.of(context).colorScheme.onErrorContainer),
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
                  const Text(
                    'შედეგი',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _ResultBlock(
                    text: state.result,
                    monospace: isEncrypt,
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
    );
  }

  void _showShareDialog(BuildContext context) {
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: kShareLink,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
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
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('ლინკის კოპირება'),
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: kShareLink),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('ლინკი დაკოპირდა'),
                    duration: Duration(seconds: 1),
                  ),
                );
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

class _ResultBlock extends StatelessWidget {
  const _ResultBlock({required this.text, required this.monospace});

  final String text;
  final bool monospace;

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
              fontSize: monospace ? 18 : 16,
              height: 1.6,
              letterSpacing: monospace ? 1.5 : null,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('კოპირება'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('დაკოპირდა'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
