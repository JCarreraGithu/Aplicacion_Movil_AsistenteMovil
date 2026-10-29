import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String title;
  final String status;
  final String change;

  const MetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.title,
    required this.status,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: AppColors.leaf,
                size: 23,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  change,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Text(
            value,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.muted,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            status,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
