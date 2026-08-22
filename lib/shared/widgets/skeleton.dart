import 'package:flutter/material.dart';

/// Base shimmering placeholder box. A plain [AnimationController]-driven
/// gradient sweep — no external shimmer package needed for something this
/// simple, and it keeps the dependency list unchanged.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1 - t, 0),
              end: Alignment(1 - t, 0),
              colors: [
                base.withValues(alpha: 0.06),
                base.withValues(alpha: 0.14),
                base.withValues(alpha: 0.06),
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// A single skeleton row shaped like the app's usual `Card(ListTile(...))`
/// rows (leading avatar, title line, subtitle line, optional trailing chip).
class SkeletonCard extends StatelessWidget {
  final bool leadingCircle;
  final bool trailing;
  final double height;

  const SkeletonCard({
    super.key,
    this.leadingCircle = true,
    this.trailing = true,
    this.height = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: height - 32,
          child: Row(
            children: [
              if (leadingCircle) ...[
                const SkeletonBox(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SkeletonBox(width: 160, height: 14),
                    SizedBox(height: 10),
                    SkeletonBox(width: 100, height: 12),
                  ],
                ),
              ),
              if (trailing) ...[
                const SizedBox(width: 16),
                const SkeletonBox(width: 56, height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A scrollable list of [SkeletonCard]s — the usual full-page loading state
/// for list-shaped screens (customers, queue, staff, payments, CRM…).
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;
  final bool leadingCircle;
  final Widget? header;

  const SkeletonList({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 84,
    this.padding = const EdgeInsets.all(24),
    this.leadingCircle = true,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        if (header != null) ...[header!, const SizedBox(height: 16)],
        for (int i = 0; i < itemCount; i++) ...[
          SkeletonCard(height: itemHeight, leadingCircle: leadingCircle),
          if (i != itemCount - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// A single stat-tile-shaped placeholder, matching the dashboard's
/// icon + label + big number cards.
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const SkeletonBox(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 70, height: 12),
                    SizedBox(height: 10),
                    SkeletonBox(width: 50, height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A `Wrap` of [SkeletonStatCard]s — the dashboard/reports summary row.
class SkeletonStatRow extends StatelessWidget {
  final int count;
  const SkeletonStatRow({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 16,
    children: List.generate(count, (_) => const SkeletonStatCard()),
  );
}
