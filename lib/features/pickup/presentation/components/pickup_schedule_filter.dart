import 'package:flutter/material.dart';

/// Read-only first-mile filtering, not schedule or Courier assignment selection.
class PickupScheduleFilter extends StatelessWidget {
  const PickupScheduleFilter({
    required this.selectedId,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String? selectedId;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Pickup schedule'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedId,
              isExpanded: true,
              itemHeight: null,
              hint: const Text('All schedules (unfiltered)'),
              onChanged: options.isEmpty ? null : onChanged,
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('All schedules (unfiltered)'),
                  ),
                ),
                for (final option in options.entries)
                  DropdownMenuItem<String>(
                    value: option.key,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Schedule ${option.value}'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choices come from the loaded unfiltered task page, not all schedules. Clear the filter to return to unfiltered work.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (selectedId != null)
          TextButton.icon(
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Clear schedule filter'),
          ),
      ],
    );
  }
}
