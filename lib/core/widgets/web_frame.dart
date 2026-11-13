import 'package:flutter/material.dart';

/// Na janela larga, impede a página de esticar de ponta a ponta.
/// Abaixo de [breakpoint] o filho volta igual, e o celular não muda.
class WebFrame extends StatelessWidget {
  const WebFrame({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.breakpoint = 840,
  });

  final Widget child;
  final double maxWidth;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < breakpoint) return child;
    return SizedBox.expand(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: child,
          ),
        ),
      ),
    );
  }
}
