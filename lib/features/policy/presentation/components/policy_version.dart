part of '../policy_screen.dart';

class PolicyVersionScreen extends StatelessWidget {
  const PolicyVersionScreen({required this.document, super.key});

  final PolicyDocument document;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${document.label} v${document.version.version}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Historical version',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Version ${document.version.version} • ${_formatDate(context, document.version.publishedAt)}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (document.version.changeSummary != null) ...[
            const SizedBox(height: 14),
            Text(document.version.changeSummary!),
          ],
          const SizedBox(height: 20),
          SelectableText(
            document.version.content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
