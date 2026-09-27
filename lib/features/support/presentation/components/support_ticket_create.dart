part of '../support_ticket_screen.dart';

class SupportTicketCreateScreen extends StatefulWidget {
  const SupportTicketCreateScreen({
    required this.controller,
    required this.authController,
    super.key,
  });

  final SupportTicketController controller;
  final AuthController authController;

  @override
  State<SupportTicketCreateScreen> createState() =>
      _SupportTicketCreateScreenState();
}

class _SupportTicketCreateScreenState extends State<SupportTicketCreateScreen> {
  late final TextEditingController _subject;
  late final TextEditingController _body;
  late String _category;
  bool _allowPop = false;

  bool get _hasDraft =>
      _subject.text.trim().isNotEmpty ||
      _body.text.trim().isNotEmpty ||
      widget.controller.pendingCreate != null;

  @override
  void initState() {
    super.initState();
    _subject = TextEditingController(
      text: widget.controller.createSubjectDraft,
    );
    _body = TextEditingController(text: widget.controller.createBodyDraft);
    _category = widget.controller.createCategoryDraft;
    widget.authController.addListener(_leaveOnSessionChange);
  }

  @override
  void dispose() {
    widget.authController.removeListener(_leaveOnSessionChange);
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _leaveOnSessionChange() {
    if (widget.authController.status == AuthStatus.authenticated) return;
    _subject.clear();
    _body.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<void> _submit() async {
    final ticket = await widget.controller.createTicket(
      subject: _subject.text,
      category: _category,
      body: _body.text,
    );
    if (ticket != null && mounted) {
      _allowPop = true;
      Navigator.of(context).pop(ticket);
    }
  }

  Future<void> _requestClose() async {
    if (!_hasDraft) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard ticket draft?'),
        content: const Text(
          'Your unsent ticket text and any pending exact retry will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard draft'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    widget.controller.updateCreateDraft(subject: '', body: '');
    widget.controller.discardPendingCreate();
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestClose());
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.controller, widget.authController]),
        builder: (context, child) {
          final busy =
              widget.controller.createStatus ==
              SupportTicketMutationStatus.submitting;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Create support ticket'),
              leading: IconButton(
                onPressed: _requestClose,
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                const Text(
                  'Describe one issue for Admin support. Do not include passwords, payment details, or private evidence.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _subject,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Briefly describe the issue',
                  ),
                  onChanged: (value) =>
                      widget.controller.updateCreateDraft(subject: value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(value: 'account', child: Text('Account')),
                    DropdownMenuItem(value: 'order', child: Text('Order')),
                    DropdownMenuItem(
                      value: 'delivery',
                      child: Text('Delivery'),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _category = value);
                          widget.controller.updateCreateDraft(category: value);
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _body,
                  maxLength: 2000,
                  minLines: 5,
                  maxLines: 10,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Explain what happened and what help you need',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (value) =>
                      widget.controller.updateCreateDraft(body: value),
                ),
                if (widget.controller.createError case final error?) ...[
                  const SizedBox(height: 8),
                  _SupportTicketNotice(
                    message: error,
                    icon: Icons.info_outline,
                    liveRegion: true,
                  ),
                ],
                if (widget.controller.pendingCreate != null && !busy) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.controller.discardPendingCreate,
                    child: const Text('Discard pending retry'),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy || !widget.controller.canRetry
                      ? null
                      : _submit,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    widget.controller.pendingCreate == null
                        ? 'Create ticket'
                        : 'Retry same request',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
