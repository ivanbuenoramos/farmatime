import 'package:flutter/material.dart';

class BaseCard extends StatelessWidget {

  final String? title;
  final String? description;
  final List<Widget>? children;

  const BaseCard({
    super.key,
    this.title,
    this.description,
    this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)...[
            Text(
              title!,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Divider(),
          ],

          if (children != null) ...[
            ...children!,
          ],

        ],
      ),
    );
  }
}