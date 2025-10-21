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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)...[
              Text(
                title!,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(height: 12),
            ],
        
            if (children != null) ...[
              ...children!,
            ],
        
          ],
        ),
      ),
    );
  }
}