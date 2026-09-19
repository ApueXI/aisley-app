part of '../pickup_screen.dart';

class PickupRouteScreen extends StatefulWidget {
  const PickupRouteScreen({
    required this.pickupController,
    required this.scheduleId,
    this.schedule,
    super.key,
  });

  final PickupController pickupController;
  final String scheduleId;
  final PickupSchedule? schedule;

  @override
  State<PickupRouteScreen> createState() => _PickupRouteScreenState();
}

class _PickupRouteScreenState extends State<PickupRouteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.pickupController.loadRouteManifest(widget.scheduleId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.pickupController,
      builder: (context, child) {
        final controller = widget.pickupController;
        final status =
            controller.routeStatuses[widget.scheduleId] ??
            PickupSectionStatus.idle;
        final manifest = controller.routeManifests[widget.scheduleId];
        final error = controller.routeErrors[widget.scheduleId];
        return Scaffold(
          appBar: AppBar(title: const Text('Pickup route order')),
          body: RefreshIndicator(
            onRefresh: () async {
              controller.routeStatuses.remove(widget.scheduleId);
              await controller.loadRouteManifest(widget.scheduleId);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _RouteSummary(schedule: widget.schedule, manifest: manifest),
                const SizedBox(height: 16),
                if (status == PickupSectionStatus.loading && manifest == null)
                  const _PickupLoadingState()
                else if (manifest == null && error != null)
                  _PickupErrorState(
                    message: error,
                    status: status,
                    onRetry: () =>
                        controller.loadRouteManifest(widget.scheduleId),
                    onOpenPolicies: () {},
                    showPolicyAction: false,
                  )
                else if (manifest != null) ...[
                  _RouteStatusBanner(manifest: manifest),
                  const SizedBox(height: 16),
                  if (manifest.stops.isEmpty)
                    const _PickupEmptyState(title: 'route stops')
                  else
                    ..._routeStopWidgets(context, manifest.stops),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.schedule, required this.manifest});

  final PickupSchedule? schedule;
  final PickupRouteManifest? manifest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Authorized stop order',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'This is a schedule-scoped pickup sequence. It is not a Buyer delivery route.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (_formatWindow(schedule) != null) ...[
          const SizedBox(height: 8),
          Text(_formatWindow(schedule)!),
        ],
        if (manifest?.calculatedAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Calculated ${_formatManilaTimestamp(manifest!.calculatedAt!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _RouteStatusBanner extends StatelessWidget {
  const _RouteStatusBanner({required this.manifest});

  final PickupRouteManifest manifest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (message, icon) = switch (manifest.status) {
      RouteManifestStatus.pending => (
        'The route manifest is still being prepared. Pickup details remain available.',
        Icons.hourglass_top_outlined,
      ),
      RouteManifestStatus.ready => (
        'The server provided an ordered route. This screen keeps the stop list available without requiring map tiles.',
        Icons.route_outlined,
      ),
      RouteManifestStatus.unavailable => (
        'Route presentation is unavailable. Continue with the authorized stop and address list.',
        Icons.route_outlined,
      ),
      RouteManifestStatus.unknown => (
        'The server returned an unsupported route state. Continue with the stop list if present.',
        Icons.info_outline,
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

List<Widget> _routeStopWidgets(
  BuildContext context,
  List<PickupRouteStop> stops,
) {
  final ordered = List<PickupRouteStop>.from(stops)
    ..sort((a, b) => a.sequence.compareTo(b.sequence));
  return [
    for (final stop in ordered) ...[
      Semantics(
        container: true,
        label: _routeStopSemantics(stop),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 18, child: Text('${stop.sequence + 1}')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.isHub ? 'Logistics hub' : 'Pickup stop',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (stop.addressSummary != null) ...[
                        const SizedBox(height: 4),
                        Text(stop.addressSummary!),
                      ],
                      if (stop.orderReferences.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Orders: ${stop.orderReferences.join(', ')}'),
                      ],
                      if (stop.reachable == false) ...[
                        const SizedBox(height: 6),
                        Text(
                          'This stop is unreachable in the current manifest.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
    ],
  ];
}

String _routeStopSemantics(PickupRouteStop stop) {
  final label = stop.isHub ? 'Logistics hub' : 'Pickup stop';
  return [
    '$label ${stop.sequence + 1}',
    if (stop.addressSummary != null) stop.addressSummary!,
    if (stop.orderReferences.isNotEmpty)
      'Orders ${stop.orderReferences.join(', ')}',
    if (stop.reachable == false) 'unreachable in current manifest',
  ].join('. ');
}
