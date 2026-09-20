// File: lib/widgets/settings_tile.dart

import 'package:flutter/material.dart';

/// Khối Gom nhóm Các dòng Cài đặt (Material 3 Surface Group)
class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerLow
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(children: _buildChildrenWithDividers(context)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChildrenWithDividers(BuildContext context) {
    final List<Widget> items = [];
    for (int i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) {
        items.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 56,
            color: Theme.of(context).dividerColor.withOpacity(0.4),
          ),
        );
      }
    }
    return items;
  }
}

/// Dòng cài đặt tiêu chuẩn (Settings Tile)
class SettingsTile extends StatelessWidget {
  final IconData leadingIcon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final String? valueText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDanger;
  final bool enabled;

  const SettingsTile({
    super.key,
    required this.leadingIcon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.valueText,
    this.trailing,
    this.onTap,
    this.isDanger = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveIconColor = isDanger
        ? theme.colorScheme.error
        : (iconColor ?? (isDark ? Colors.white70 : theme.primaryColor));

    final effectiveTitleColor = isDanger
        ? theme.colorScheme.error
        : (enabled
              ? (isDark ? Colors.white : Colors.black87)
              : theme.disabledColor);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDanger
                    ? theme.colorScheme.error.withOpacity(0.12)
                    : (iconColor ?? theme.primaryColor).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(leadingIcon, size: 20, color: effectiveIconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: effectiveTitleColor,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (valueText != null && valueText!.isNotEmpty) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  valueText!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dòng cài đặt Bật/Tắt (Settings Switch Tile)
class SettingsSwitchTile extends StatelessWidget {
  final IconData leadingIcon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  const SettingsSwitchTile({
    super.key,
    required this.leadingIcon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveIconColor =
        iconColor ?? (isDark ? Colors.white70 : theme.primaryColor);

    return InkWell(
      onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? theme.primaryColor).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(leadingIcon, size: 20, color: effectiveIconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? (isDark ? Colors.white : Colors.black87)
                          : theme.disabledColor,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: theme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
