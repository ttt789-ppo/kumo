import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// 圆角卡片，BakaSU 那种一片一片的样子
class KsuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const KsuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).cardColor;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(KumoTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 分组小标题，例如「版本信息」「状态信息」
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 22, 8, 10),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 状态大卡：左边状态图标 + 标题 + 徽章，下面一行说明
class StatusBanner extends StatelessWidget {
  final String title;
  final String? badge;
  final String subtitle;
  final bool ok;
  final IconData icon;
  final VoidCallback? onTap;

  const StatusBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.ok,
    required this.icon,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = ok ? scheme.primary : scheme.error;
    final fg = ok ? Colors.white : Colors.white;
    return Material(
      borderRadius: BorderRadius.circular(KumoTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      color: base,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(Colors.white.withOpacity(0.14), base),
                base,
                Color.alphaBlend(Colors.black.withOpacity(0.16), base),
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: fg,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: fg.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                color: fg,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(color: fg.withOpacity(0.92), fontSize: 14, height: 1.3),
                    ),
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

/// 「图标 + 标题 + 值」的一行信息
class InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const InfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return KsuCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 26, color: scheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.35),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 数字指标
class MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? color;

  const MetricBox({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: KsuCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color ?? scheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(sub!, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 折线面积图（查询量趋势）
class Sparkline extends StatelessWidget {
  final List<double> data;
  final List<double>? second;
  final double height;
  final Color? color;

  const Sparkline({
    super.key,
    required this.data,
    this.second,
    this.height = 96,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(
          data,
          second: second,
          line: color ?? scheme.primary,
          fill: (color ?? scheme.primary).withOpacity(0.16),
          grid: scheme.outlineVariant.withOpacity(0.35),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final List<double>? second;
  final Color line;
  final Color fill;
  final Color grid;

  _SparkPainter(this.data, {this.second, required this.line, required this.fill, required this.grid});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (data.isEmpty) return;
    final maxV = [
      ...data,
      ...(second ?? const <double>[]),
    ].fold<double>(1, (a, b) => math.max(a, b));

    Path pathFor(List<double> s) {
      final p = Path();
      for (var i = 0; i < s.length; i++) {
        final x = s.length == 1 ? 0.0 : size.width * i / (s.length - 1);
        final y = size.height - (s[i] / maxV) * (size.height - 6) - 3;
        if (i == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      return p;
    }

    final linePath = pathFor(data);
    final areaPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(areaPath, Paint()..color = fill);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (second != null && second!.isNotEmpty) {
      canvas.drawPath(
        pathFor(second!),
        Paint()
          ..color = line.withOpacity(0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.data != data || old.second != second || old.line != line;
}

/// 空状态
class EmptyBox extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyBox(this.text, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        child: Column(
          children: [
            Icon(icon, size: 40, color: c.withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: c, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

/// 顶部大标题 + 右侧按钮，BakaSU 的顶栏
class KsuHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  const KsuHeader({super.key, required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: BigTitle(title)),
        ...actions,
      ],
    );
  }
}
