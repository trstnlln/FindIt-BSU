import 'package:flutter/material.dart';

/// Approval is distinct from pickup readiness and a completed handover.
class ClaimJourney extends StatelessWidget {
  final String status;
  final bool returned;
  const ClaimJourney({super.key, required this.status, this.returned = false});
  @override
  Widget build(BuildContext context) {
    if (status == 'rejected') {
      return const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Claim not approved'),
        subtitle: Text('The reporter could not confirm ownership.'),
      );
    }
    const steps = [
      'Submitted',
      'Under review',
      'Approved',
      'Ready for pickup',
      'Returned',
    ];
    final active = returned
        ? 4
        : switch (status) {
            'reviewing' => 1,
            'approved' => 2,
            'ready' => 3,
            'returned' => 4,
            _ => 0,
          };
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your recovery journey',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(
                  entry.key <= active
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 19,
                  color: entry.key <= active
                      ? color
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontWeight: entry.key == active
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
