


import 'package:flutter/material.dart';

class SoldierCard extends StatelessWidget {
  final String name;
  final String unit;
  final String uniqueNumber; 
  final String? status;
  final Color? statusColor;
  final VoidCallback? onEditName;

  const SoldierCard({
    required this.name,
    required this.unit,
    required this.uniqueNumber,
    this.status,
    this.statusColor,
    this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(
                name.isNotEmpty ? name[0] : '?',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (onEditName != null)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Изменить имя',
                          onPressed: onEditName,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // --- ПОДРАЗДЕЛЕНИЕ ---
                  Text(
                    unit,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),

                  // --- ✅ УНИКАЛЬНЫЙ НОМЕР ---
                  const SizedBox(height: 2),
                  Text(
                    'ID: $uniqueNumber',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.withOpacity(0.8),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // --- СТАТУС ---
                  if (status != null && status!.isNotEmpty) ...[
                    Row(
                      children: [
                        if (statusColor != null)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (statusColor != null) const SizedBox(width: 6),
                        Text(
                          status!,
                          style: TextStyle(
                            fontSize: 14,
                            color: statusColor ?? Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}