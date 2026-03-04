import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  PackageInfo? _packageInfo;

  String get versionText => _packageInfo == null
      ? 'Unknown'
      : '${_packageInfo!.version}+${_packageInfo!.buildNumber}';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      setState(() {
        _packageInfo = info;
      });
    } catch (_) {
      // Best-effort only; keep screen usable when package info is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final headingStyle = Theme.of(context).textTheme.titleMedium;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    final mutedStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.black54);

    Widget section({required String title, required List<String> paragraphs}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: headingStyle),
            const SizedBox(height: 6),
            for (final p in paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(p, style: bodyStyle),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Help / Info / FAQ')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              section(
                title: 'About The Game',
                paragraphs: const [
                  'Spider Solitaire with 1-suit, 2-suit, and 4-suit difficulty modes.',
                  '1-suit is the most accessible, 2-suit is medium, and 4-suit is the classic hardest mode.',
                ],
              ),
              section(
                title: 'How To Play',
                paragraphs: const [
                  'Build descending runs in the tableau (K down to A).',
                  'Complete full same-suit sequences to remove them to foundations.',
                  'Deal a new stock row when you need more moves.',
                ],
              ),
              section(
                title: 'Daily And Guaranteed Deals',
                paragraphs: const [
                  'Guaranteed deals are solver-verified solvable under STRICT rules.',
                  'The verified pool is generated offline with time limits, so it grows gradually.',
                ],
              ),
              section(
                title: 'Strict Rules And User Options',
                paragraphs: const [
                  'Verification always uses strict canonical rules and is not affected by your settings.',
                  'If you enable relaxed gameplay options (for example unrestricted stock deal behavior), that affects your play session but not solver verification.',
                ],
              ),
              section(
                title: 'Privacy And Data',
                paragraphs: const [
                  'No account. No personal data collected. Gameplay data stored locally on your device.',
                  'This app uses local storage for saves, settings, stats, and solvable-seed usage tracking.',
                  'No analytics or crash-reporting SDKs are integrated in this build.',
                ],
              ),
              section(
                title: 'App Version',
                paragraphs: ['Version / Build: $versionText'],
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Open Licenses'),
                subtitle: Text(
                  'View open-source licenses used by this app.',
                  style: mutedStyle,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Haylau Spider Solitaire',
                    applicationVersion: versionText,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
