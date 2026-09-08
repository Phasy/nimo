import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../accounts/presentation/accounts_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'More',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Manage your money and app settings.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 28),

            _MoreSection(
              title: 'Money',
              children: [
                _MoreMenuItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Accounts',
                  subtitle: 'See where your money is',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AccountsScreen(),
                      ),
                    );
                  },
                ),

                _MoreMenuItem(
                  icon: Icons.flag_outlined,
                  title: 'Goals',
                  subtitle: 'Track savings goals',
                  onTap: () {
                    _showComingSoon(context, 'Goals');
                  },
                ),

                _MoreMenuItem(
                  icon: Icons.repeat_rounded,
                  title: 'Recurring',
                  subtitle: 'Manage planned payments',
                  onTap: () {
                    _showComingSoon(
                      context,
                      'Recurring transactions',
                    );
                  },
                ),

                _MoreMenuItem(
                  icon: Icons.bar_chart_rounded,
                  title: 'Reports',
                  subtitle: 'Understand your finances',
                  onTap: () {
                    _showComingSoon(context, 'Reports');
                  },
                ),
              ],
            ),

            const SizedBox(height: 26),

            _MoreSection(
              title: 'Automation',
              children: [
                _MoreMenuItem(
                  icon: Icons.sms_outlined,
                  title: 'SMS Inbox',
                  subtitle: 'Review detected transactions',
                  onTap: () {
                    _showComingSoon(context, 'SMS Inbox');
                  },
                ),
              ],
            ),

            const SizedBox(height: 26),

            _MoreSection(
              title: 'Application',
              children: [
                _MoreMenuItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'Categories, data and preferences',
                  onTap: () {
                    _showComingSoon(context, 'Settings');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void _showComingSoon(
      BuildContext context,
      String feature,
      ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _MoreSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _MoreSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),

        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.border,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int index = 0; index < children.length; index++) ...[
                children[index],

                if (index != children.length - 1)
                  const Divider(
                    height: 1,
                    indent: 72,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryDark,
                  size: 21,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                      Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}