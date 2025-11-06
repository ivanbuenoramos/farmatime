import 'package:flutter/material.dart';

class BaseCard extends StatelessWidget {

  final String? title;
  final String? description;
  final List<Widget>? children;
  final List<Widget>? actions;

  const BaseCard({
    super.key,
    this.title,
    this.description,
    this.children,
    this.actions,
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
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