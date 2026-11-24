// Deskcel (Hostcel): cores, textos, ícones e botões do modelo deskcel-layout.html.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Dk {
  Dk._();

  static const off = Color(0xFFF2EFEA);
  static const branco = Color(0xFFFFFFFF);
  static const linha = Color(0xFFE6E0D8);
  static const tinta = Color(0xFF211713);
  static const apoio = Color(0xFF6B615A);
  static const laranja = Color(0xFFEC7A2C);
  static const terracota = Color(0xFFA8461C);
  static const ok = Color(0xFF2F8F55);
  static const areia = Color(0xFFEAE5DE);

  static const rCartao = 28.0;
  static const rCampo = 22.0;

  static const fonte = 'Outfit';
  static const mono = 'JetBrainsMono';

  /// Equivale ao `font: peso tamanho/linha` do CSS, com `letter-spacing` em em.
  static TextStyle t(double size, FontWeight weight, double line,
          {Color color = tinta, double ls = 0, String family = fonte}) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        height: line / size,
        leadingDistribution: TextLeadingDistribution.even,
        letterSpacing: ls * size,
        color: color,
      );

  static final marca = t(16, FontWeight.w600, 16, ls: -.03);
  static final marca2 = t(12, FontWeight.w400, 16, color: apoio);
  static final tit = t(22, FontWeight.w600, 32, ls: -.03);
  static final sub = t(16, FontWeight.w600, 24, ls: -.03);
  static final desc = t(13, FontWeight.w400, 20, color: apoio);
  static final rot = t(13, FontWeight.w500, 20);
  static final et = t(11, FontWeight.w500, 16, color: apoio, ls: .08, family: mono);
  static final id = t(24, FontWeight.w500, 32, family: mono);
  static final senha = t(24, FontWeight.w600, 32, ls: .04);
  static final item = t(14, FontWeight.w500, 20);
  static final idp = t(12, FontWeight.w500, 20, color: apoio, family: mono);
  static final peq = t(12, FontWeight.w400, 16, color: apoio);
  static final data = t(12, FontWeight.w400, 20, color: apoio);
  static final campo = t(16, FontWeight.w500, 20, family: mono);
  static final btnP = t(15, FontWeight.w600, 20);
  static final btnS = t(14, FontWeight.w500, 20);
  static final barra = t(12, FontWeight.w400, 32);

}

/// Cartão: branco, borda 1 px por cima (como o `inset` do modelo, sem deslocar o conteúdo), raio 28.
class DkCard extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget child;
  final double radius;
  const DkCard(
      {Key? key,
      this.width,
      this.height,
      required this.child,
      this.radius = Dk.rCartao})
      : super(key: key);

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
            color: Dk.branco, borderRadius: BorderRadius.circular(radius)),
        foregroundDecoration: BoxDecoration(
            border: Border.all(color: Dk.linha, width: 1),
            borderRadius: BorderRadius.circular(radius)),
        child: child,
      );
}

/// Ícones do modelo: grade 24, traço 1,8, sem preenchimento.
const Map<String, String> _dkPaths = {
  'copiar':
      '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15H4.5A1.5 1.5 0 0 1 3 13.5v-9A1.5 1.5 0 0 1 4.5 3h9A1.5 1.5 0 0 1 15 4.5V5"/>',
  'nova':
      '<path d="M20 11a8 8 0 0 0-14.9-3.5M4 4v4h4M4 13a8 8 0 0 0 14.9 3.5M20 20v-4h-4"/>',
  'monitor': '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/>',
  'pasta':
      '<path d="M3.5 7.5a2 2 0 0 1 2-2H10l2 2h6.5a2 2 0 0 1 2 2v8.5a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z"/><path d="M9 13.5h6M13 11.5l2 2-2 2"/>',
  'escudo': '<path d="M12 3 5 6v5c0 4.5 3 8 7 10 4-2 7-5.5 7-10V6z"/><path d="m9 12 2 2 4-4"/>',
  'seta': '<path d="M5 12h14M14 7l5 5-5 5"/>',
  'voltar': '<path d="M19 12H5M10 7l-5 5 5 5"/>',
  'pessoa': '<circle cx="12" cy="8.5" r="3.6"/><path d="M5 20c1-3.6 3.8-5.4 7-5.4s6 1.8 7 5.4"/>',
  'teclado': '<rect x="3" y="6" width="18" height="12" rx="2"/><path d="M7 10h.01M11 10h.01M15 10h.01M7 14h10"/>',
  'prancheta':
      '<rect x="8" y="3" width="8" height="4" rx="1"/><path d="M16 5h1.5A1.5 1.5 0 0 1 19 6.5v13a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 5 19.5v-13A1.5 1.5 0 0 1 6.5 5H8"/>',
  'arquivo': '<path d="M6 3h8l4 4v14H6zM14 3v4h4"/>',
  'audio': '<path d="M4 9.5h3.5L12 6v12l-4.5-3.5H4zM16 9a4 4 0 0 1 0 6M18.5 6.5a7.5 7.5 0 0 1 0 11"/>',
  'encerrar': '<path d="M12 3v9M7 6.3a7.5 7.5 0 1 0 10 0"/>',
  'check': '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  'x': '<path d="m6 6 12 12M18 6 6 18"/>',
  'relogio': '<circle cx="12" cy="12" r="9"/><path d="M12 7.5V12l3 2"/>',
  'cadeado': '<rect x="5" y="11" width="14" height="9.5" rx="2.5"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
  'rede':
      '<path d="M2.5 9a14 14 0 0 1 19 0M5.5 12.5a9.5 9.5 0 0 1 13 0M8.5 16a5 5 0 0 1 7 0M12 19.5h.01"/>',
  'info': '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
  'baixar': '<path d="M12 4v11M7.5 10.5 12 15l4.5-4.5M5 19.5h14"/>',
  'config':
      '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>',
  'mais': '<circle cx="12" cy="5.5" r=".6"/><circle cx="12" cy="12" r=".6"/><circle cx="12" cy="18.5" r=".6"/>',
};

String _hex(Color c) =>
    '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

class DkIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const DkIcon(this.name, {Key? key, this.size = 20, this.color = Dk.tinta})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="${_hex(color)}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${_dkPaths[name] ?? ''}</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}

/// Símbolo Hostcel (fundo tinta com as três barras).
class DkSimbolo extends StatelessWidget {
  final double size;
  const DkSimbolo({Key? key, this.size = 32}) : super(key: key);

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/icon.svg', width: size, height: size);
}

/// Botão redondo só com ícone (40 × 40 sobre cartão, 32 × 32 na barra).
class DkIconButton extends StatelessWidget {
  final String icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color background;
  final bool border;
  final Color? iconColor;
  const DkIconButton(this.icon,
      {Key? key,
      this.onTap,
      this.tooltip,
      this.size = 40,
      this.iconSize = 20,
      this.background = Dk.off,
      this.border = false,
      this.iconColor})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final w = Material(
      color: background,
      shape: CircleBorder(
          side: border
              ? const BorderSide(color: Dk.linha, width: 1)
              : BorderSide.none),
      child: InkWell(
        customBorder: const CircleBorder(),
        hoverColor: Dk.tinta.withOpacity(.06),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
              child: DkIcon(icon,
                  size: iconSize,
                  color: iconColor ?? (enabled ? Dk.tinta : Dk.apoio))),
        ),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}

/// Botão principal: 48 px, laranja, texto tinta 15/600.
class DkPrimaryButton extends StatelessWidget {
  final String label;
  final String? icon;
  final bool iconAfter;
  final VoidCallback? onTap;
  final double? width;
  const DkPrimaryButton(this.label,
      {Key? key, this.icon, this.iconAfter = false, this.onTap, this.width})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ic = icon == null ? null : DkIcon(icon!, color: Dk.tinta);
    return SizedBox(
      width: width,
      height: 48,
      child: Material(
        color: Dk.laranja,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          hoverColor: Dk.tinta.withOpacity(.08),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ic != null && !iconAfter) ...[ic, const SizedBox(width: 8)],
              Text(label, style: Dk.btnP),
              if (ic != null && iconAfter) ...[const SizedBox(width: 8), ic],
            ],
          ).paddingSymmetric(16),
        ),
      ),
    );
  }
}

/// Botão secundário: fundo branco, borda 1 px, texto 14/500, ícone terracota.
class DkSecondaryButton extends StatelessWidget {
  final String label;
  final String? icon;
  final VoidCallback? onTap;
  final double? width;
  final double height;
  final TextStyle? style;
  final Color iconColor;
  final double iconSize;
  final double gap;
  const DkSecondaryButton(this.label,
      {Key? key,
      this.icon,
      this.onTap,
      this.width,
      this.height = 40,
      this.style,
      this.iconColor = Dk.terracota,
      this.iconSize = 20,
      this.gap = 8})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Dk.branco,
        shape: const StadiumBorder(side: BorderSide(color: Dk.linha, width: 1)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          hoverColor: Dk.tinta.withOpacity(.04),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                DkIcon(icon!, size: iconSize, color: iconColor),
                SizedBox(width: gap)
              ],
              Text(label, style: style ?? Dk.btnS),
            ],
          ).paddingSymmetric(16),
        ),
      ),
    );
  }
}

/// Chave liga/desliga do modelo (40 × 24).
class DkSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const DkSwitch({Key? key, required this.value, this.onChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onChanged == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Container(
          width: 40,
          height: 24,
          decoration: BoxDecoration(
            color: value ? Dk.laranja : Dk.branco,
            borderRadius: BorderRadius.circular(999),
          ),
          foregroundDecoration: value
              ? null
              : BoxDecoration(
                  border: Border.all(color: Dk.apoio, width: 1),
                  borderRadius: BorderRadius.circular(999)),
          child: Stack(children: [
            Positioned(
              left: value ? 20 : 6,
              top: value ? 4 : 6,
              child: Container(
                width: value ? 16 : 12,
                height: value ? 16 : 12,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? Dk.branco : Dk.apoio),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

extension _DkPad on Widget {
  Widget paddingSymmetric(double h) =>
      Padding(padding: EdgeInsets.symmetric(horizontal: h), child: this);
}

/// Botões da barra de título no padrão do Windows 11 (46 × 32, desenho de 10 px, traço 1).
class DkWinButton extends StatefulWidget {
  final String kind; // min, max, restore, close
  final VoidCallback? onTap;
  final String? tooltip;
  const DkWinButton(this.kind, {Key? key, this.onTap, this.tooltip})
      : super(key: key);

  @override
  State<DkWinButton> createState() => _DkWinButtonState();
}

class _DkWinButtonState extends State<DkWinButton> {
  bool _hover = false;
  static const _glyph = {
    'min': '<path d="M0 5.5h10"/>',
    'max': '<rect x=".5" y=".5" width="9" height="9" rx="1.5"/>',
    'restore':
        '<rect x=".5" y="2.5" width="7" height="7" rx="1.5"/><path d="M2.5 2.5V2A1.5 1.5 0 0 1 4 .5h4A1.5 1.5 0 0 1 9.5 2v4A1.5 1.5 0 0 1 8 7.5h-.5"/>',
    'close': '<path d="m.5.5 9 9M9.5.5l-9 9"/>',
  };

  @override
  Widget build(BuildContext context) {
    final isClose = widget.kind == 'close';
    final color = _hover && isClose ? Dk.branco : Dk.tinta;
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" fill="none" stroke="${_hex(color)}" stroke-width="1">${_glyph[widget.kind]}</svg>';
    final w = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 32,
          color: _hover
              ? (isClose ? const Color(0xFFC42B1C) : Dk.tinta.withOpacity(.06))
              : Colors.transparent,
          alignment: Alignment.center,
          child: SvgPicture.string(svg, width: 10, height: 10),
        ),
      ),
    );
    return widget.tooltip == null
        ? w
        : Tooltip(
            message: widget.tooltip!,
            waitDuration: const Duration(seconds: 1),
            child: w);
  }
}
