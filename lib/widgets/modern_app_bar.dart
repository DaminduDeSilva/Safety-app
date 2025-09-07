import 'package:flutter/material.dart';

/// Modern and consistent app bar widget used across all screens.
///
/// Features gradient background, proper elevation, and consistent styling
/// that makes the app look professional and polished.
class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final VoidCallback? onBack;

  const ModernAppBar({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[600]!, Colors.blue[800]!],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: automaticallyImplyLeading,
        leading:
            leading ??
            (automaticallyImplyLeading && Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: onBack ?? () => Navigator.pop(context),
                  )
                : null),
        actions: actions?.map((action) {
          // Ensure action icons are white
          if (action is IconButton) {
            return IconButton(
              icon: Icon((action.icon as Icon).icon, color: Colors.white),
              onPressed: action.onPressed,
            );
          }
          return action;
        }).toList(),
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Modern card widget with consistent styling and subtle animations
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double? elevation;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation ?? 4,
      shadowColor: Colors.grey.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(20.0),
          child: child,
        ),
      ),
    );
  }
}

/// Modern gradient button with consistent styling
class ModernGradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final List<Color>? gradientColors;
  final double? width;
  final double height;
  final IconData? icon;

  const ModernGradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.gradientColors,
    this.width,
    this.height = 50,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors ?? [Colors.blue[600]!, Colors.blue[800]!],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: (gradientColors?.first ?? Colors.blue).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(25),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
