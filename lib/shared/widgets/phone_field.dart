import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'page_scaffold.dart' show ScolarisThemeColors;

/// Indicatif téléphonique — liste volontairement courte (région + quelques
/// pays fréquents dans les fratries/diaspora), pas un catalogue ITU complet.
class _CountryCode {
  final String dial;
  final String flag;
  final String name;
  const _CountryCode(this.dial, this.flag, this.name);
}

const _kCountryCodes = [
  _CountryCode('+242', '🇨🇬', 'Congo-Brazzaville'),
  _CountryCode('+243', '🇨🇩', 'RD Congo'),
  _CountryCode('+237', '🇨🇲', 'Cameroun'),
  _CountryCode('+241', '🇬🇦', 'Gabon'),
  _CountryCode('+235', '🇹🇩', 'Tchad'),
  _CountryCode('+236', '🇨🇫', 'Centrafrique'),
  _CountryCode('+33', '🇫🇷', 'France'),
  _CountryCode('+1', '🇺🇸', 'États-Unis / Canada'),
];

/// Champ téléphone avec sélecteur d'indicatif, au lieu de compter sur une
/// saisie manuelle de « +242 » (fautes de frappe, espaces, tirets…). Le
/// [controller] passé reste la source unique : cette classe n'y écrit qu'une
/// valeur normalisée `+242XXXXXXXXX` (indicatif + chiffres, sans séparateur),
/// pour que les comparaisons exactes (ex. retrouver un parent déjà inscrit
/// par téléphone, cf. `createOrLinkGuardian`) ne dépendent plus du formatage.
class PhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final bool enabled;

  const PhoneField({
    super.key,
    required this.controller,
    this.label = 'Téléphone',
    this.required = false,
    this.enabled = true,
  });

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late _CountryCode _country;
  late final TextEditingController _local;

  @override
  void initState() {
    super.initState();
    final raw = widget.controller.text.trim();
    _country = _kCountryCodes.firstWhere(
      (c) => raw.startsWith(c.dial),
      orElse: () => _kCountryCodes.first,
    );
    final rest = raw.startsWith(_country.dial)
        ? raw.substring(_country.dial.length)
        : raw;
    _local = TextEditingController(text: rest.trim());
    _local.addListener(_sync);
  }

  void _sync() {
    final digits = _local.text.replaceAll(RegExp(r'[^0-9]'), '');
    widget.controller.text = digits.isEmpty ? '' : '${_country.dial}$digits';
  }

  @override
  void dispose() {
    _local.removeListener(_sync);
    _local.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecor(BuildContext context) => InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(fontSize: 12.5, color: context.cMuted),
        isDense: true,
        filled: true,
        fillColor: context.cSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.cBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ScolarisPalette.terracotta, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: context.cSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.cBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_CountryCode>(
            value: _country,
            isDense: true,
            borderRadius: BorderRadius.circular(10),
            style: TextStyle(fontSize: 13, color: context.cInk),
            items: [
              for (final c in _kCountryCodes)
                DropdownMenuItem(
                  value: c,
                  child: Tooltip(
                    message: c.name,
                    child: Text('${c.flag} ${c.dial}'),
                  ),
                ),
            ],
            onChanged: widget.enabled
                ? (v) {
                    if (v == null) return;
                    setState(() => _country = v);
                    _sync();
                  }
                : null,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: TextFormField(
          controller: _local,
          enabled: widget.enabled,
          keyboardType: TextInputType.phone,
          style: TextStyle(fontSize: 13.5, color: context.cInk),
          decoration: _fieldDecor(context),
          validator: widget.required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Téléphone requis' : null
              : null,
        ),
      ),
    ]);
  }
}
