import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/server_config.dart';
import '../services/hotkey_service.dart';
import '../services/settings_repository.dart';
import '../services/whisper_client.dart';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({
    super.key,
    required this.repository,
    required this.onSaved,
  });

  final SettingsRepository repository;
  final void Function(ServerConfig) onSaved;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _languageController = TextEditingController();
  bool _translate = false;
  String _hotkeyId = HotkeyPreset.defaultId;
  bool _loading = true;
  bool _isTesting = false;
  String _testMessage = '';
  bool? _testOk;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await widget.repository.load();
    _hostController.text = config.host;
    _portController.text = config.port.toString();
    _languageController.text = config.language;
    _translate = config.translate;
    _hotkeyId = config.hotkeyPresetId;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  ServerConfig _buildConfig() {
    return ServerConfig(
      host: _hostController.text.trim().isEmpty
          ? ServerConfig().host
          : _hostController.text.trim(),
      port: int.tryParse(_portController.text) ?? ServerConfig().port,
      language: _languageController.text.trim().isEmpty
          ? ServerConfig().language
          : _languageController.text.trim(),
      translate: _translate,
      hotkeyPresetId: _hotkeyId,
    );
  }

  Future<void> _save() async {
    final config = _buildConfig();
    await widget.repository.save(config);
    widget.onSaved(config);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _testConnection() async {
    if (_isTesting) return;
    setState(() {
      _isTesting = true;
      _testMessage = 'Testing…';
      _testOk = null;
    });
    final result = await WhisperClient.test(_buildConfig());
    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testOk = result.ok;
      _testMessage = result.ok ? 'Connected successfully' : result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.glassBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionLabel(text: 'CONNECTION'),
                              const SizedBox(height: 8),
                              _GlassCard(
                                children: [
                                  _SettingsField(
                                    label: 'Server Host',
                                    controller: _hostController,
                                    hint: 'm5max.local',
                                    prefixIcon: Icons.dns_rounded,
                                  ),
                                  const _FieldDivider(),
                                  _SettingsField(
                                    label: 'Port',
                                    controller: _portController,
                                    hint: '9002',
                                    prefixIcon: Icons.numbers_rounded,
                                    keyboardType: TextInputType.number,
                                  ),
                                  const _FieldDivider(),
                                  _SettingsField(
                                    label: 'Language',
                                    controller: _languageController,
                                    hint: 'en',
                                    prefixIcon: Icons.language_rounded,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _SectionLabel(text: 'BEHAVIOR'),
                              const SizedBox(height: 8),
                              _GlassCard(
                                children: [
                                  _ToggleRow(
                                    icon: Icons.translate_rounded,
                                    label: 'Translate to English',
                                    value: _translate,
                                    onChanged: (v) =>
                                        setState(() => _translate = v),
                                  ),
                                  const _FieldDivider(),
                                  _DropdownRow(
                                    icon: Icons.keyboard_rounded,
                                    label: 'Hotkey',
                                    value: _hotkeyId,
                                    items: [
                                      for (final p in HotkeyPreset.all)
                                        DropdownMenuItem(
                                          value: p.id,
                                          child: Text(
                                            p.label,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _hotkeyId = v!),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildTestButton(),
                              if (_testMessage.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _buildTestResult(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.accentDim],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Configure your dictation server',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _save,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentDim],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGlow,
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _isTesting ? null : _testConnection,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: _testOk == true
                ? AppColors.greenSoft
                : _testOk == false
                    ? AppColors.redSoft
                    : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _testOk == true
                  ? AppColors.green.withValues(alpha: 0.3)
                  : _testOk == false
                      ? AppColors.red.withValues(alpha: 0.3)
                      : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              if (_isTesting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else
                Icon(
                  _testOk == true
                      ? Icons.check_circle_outline_rounded
                      : _testOk == false
                          ? Icons.error_outline_rounded
                          : Icons.cable_rounded,
                  size: 16,
                  color: _testOk == true
                      ? AppColors.green
                      : _testOk == false
                          ? AppColors.red
                          : AppColors.textSecondary,
                ),
              const SizedBox(width: 10),
              Text(
                _testMessage.isNotEmpty ? _testMessage : 'Test connection',
                style: TextStyle(
                  color: _testOk == true
                      ? AppColors.green
                      : _testOk == false
                          ? AppColors.red
                          : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestResult() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _testOk == true
            ? AppColors.greenSoft
            : AppColors.redSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _testOk == true
              ? AppColors.green.withValues(alpha: 0.3)
              : AppColors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _testOk == true
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            size: 16,
            color: _testOk == true ? AppColors.green : AppColors.red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _testMessage,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Column(children: children),
    );
  }
}

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: AppColors.glassBorder.withValues(alpha: 0.5),
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  const _SettingsField({
    required this.label,
    required this.controller,
    this.hint,
    this.prefixIcon,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.5),
                ),
                filled: true,
                fillColor: AppColors.background.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accentGlow,
            inactiveThumbColor: AppColors.textMuted,
            inactiveTrackColor: AppColors.surfaceAlt,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                dropdownColor: AppColors.surface,
                icon: Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
