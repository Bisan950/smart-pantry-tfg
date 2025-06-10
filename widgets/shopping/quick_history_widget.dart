
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/shopping_mode_service.dart';
import '../../models/purchase_record_model.dart';
import '../../config/theme.dart';
import '../../screens/shopping_history/shopping_history_screen.dart';

class QuickHistoryWidget extends StatelessWidget {
  const QuickHistoryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShoppingSession>>(
      future: context.read<ShoppingModeService>().getCompletedShoppingSessions(limit: 3),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final recentSessions = snapshot.data!;

        return Card(
          margin: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Compras Recientes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ShoppingHistoryScreen(),
                        ),
                      ),
                      child: const Text('Ver todo'),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                ...recentSessions.map((session) => _buildQuickSessionItem(context, session)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickSessionItem(BuildContext context, ShoppingSession session) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ShoppingHistoryScreen(),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSmall),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.coralMain.withOpacity(0.1),
              child: const Icon(
                Icons.shopping_cart_rounded,
                color: AppTheme.coralMain,
                size: 18,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.store ?? 'Compra',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${session.itemCount} productos • ${session.formattedStartTime}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              session.formattedTotal,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.coralMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}