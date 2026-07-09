import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/server_config.dart';
import '../../services/hotkey_service.dart';
import '../../services/settings_repository.dart';
import '../../services/whisper_client.dart';
import 'components/components.dart';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({
    super.key,
    required this.repository,
    required this.onSaved,
  });

  final SettingsRepository repository;
  final void Function(ServerConfig) onSaved;

  static Future<void> show({
    required BuildContext context,
    required SettingsRepository repository,
    required void Function(ServerConfig) onSaved,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        child: SettingsSheet(
          repository: repository,
          onSaved: onSaved,
        ),
      ),
    );
  }

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
    return _loading
        ? const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          )
        : Container(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 580),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GlassSection(
                          title: 'CONNECTION',
                          children: [
                            SettingsField(
                              label: 'Server Host',
                              controller: _hostController,
                              hint: 'm5max.local',
                              prefixIcon: Icons.dns_rounded,
                            ),
                            const FieldDivider(),
                            SettingsField(
                              label: 'Port',
                              controller: _portController,
                              hint: '9002',
                              prefixIcon: Icons.numbers_rounded,
                              keyboardType: TextInputType.number,
                            ),
                            const FieldDivider(),
                            SettingsField(
                              label: 'Language',
                              controller: _languageController,
                              hint: 'en',
                              prefixIcon: Icons.language_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        GlassSection(
                          title: 'BEHAVIOR',
                          children: [
                            SettingsToggle(
                              icon: Icons.translate_rounded,
                              label: 'Translate to English',
                              value: _translate,
                              onChanged: (v) =>
                                  setState(() => _translate = v),
                            ),
                            const FieldDivider(),
                            SettingsDropdown(
                              prefixIcon: Icons.keyboard_rounded,
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
          );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent,
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
          SettingsButton(
            label: 'Save',
            icon: Icons.check_rounded,
            onPressed: _save,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton() {
    final isSuccess = _testOk == true;
    final isError = _testOk == false;
    return SettingsButton(
      label: _testMessage.isNotEmpty ? _testMessage : 'Test connection',
      icon: isSuccess
          ? Icons.check_circle_outline_rounded
          : isError
              ? Icons.error_outline_rounded
              : Icons.cable_rounded,
      isLoading: _isTesting,
      onPressed: _isTesting ? null : _testConnection,
      isPrimary: !isError,
      backgroundColor: isSuccess
          ? AppColors.green
          : isError
              ? AppColors.red
              : null,
      expanded: true,
    );
  }

  Widget _buildTestResult() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _testOk == true ? AppColors.greenSoft : AppColors.redSoft,
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
              style: const TextStyle(
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
