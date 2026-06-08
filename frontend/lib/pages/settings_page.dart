import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/settings_controller.dart';
import '../services/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = context.watch<SettingsController>();

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          if (controller.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (controller.config == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load settings from backend',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 18),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => controller.loadSettings(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('General'),
                          _buildThemeDropdown(),
                          _buildExplorableField(
                            'Output Directory',
                            controller.outputDirController,
                            'Default folder for converted videos.',
                            () => controller.pickOutputFolder(),
                          ),
                          const SizedBox(height: 24),
                          _buildTextField(
                            'Naming Template',
                            controller.namingTemplateController,
                            'e.g. S{S:02d}E{E:02d} - {title}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildGlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Conversion'),
                          _buildSwitchTile(
                            'Review before conversion',
                            'Show a mapping of files before starting the process.',
                            controller.config!['review_before_convert'] as bool,
                            (val) => controller.setConfigValue('review_before_convert', val),
                          ),
                          _buildSwitchTile(
                            'Skip existing files',
                            'Do not re-convert files that already exist in the output folder.',
                            controller.config!['skip_existing'] as bool,
                            (val) => controller.setConfigValue('skip_existing', val),
                          ),
                          _buildSwitchTile(
                            'System Notifications',
                            'Show a Windows notification when a batch finishes.',
                            controller.config!['show_notifications'] as bool? ?? true,
                            (val) => controller.setConfigValue('show_notifications', val),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  'Max Retries',
                                  controller.maxRetriesController,
                                  'Number of attempts.',
                                  width: double.infinity,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildTextField(
                                  'Parallel Jobs',
                                  controller.parallelJobsController,
                                  'Files to convert simultaneously.',
                                  width: double.infinity,
                                ),
                              ),
                            ],
                          ),
                          _buildDropdown(
                            'Default Resolution',
                            controller.selectedRes,
                            const {
                              '1080p': '1080p (Full HD)',
                              '720p': '720p (HD)',
                              '480p': '480p (SD)',
                            },
                            (val) => controller.setSelectedRes(val),
                          ),
                          const SizedBox(height: 16),
                          _buildDropdown(
                            'Default Quality',
                            controller.selectedQuality,
                            const {
                              'high': 'High (Best Quality)',
                              'medium': 'Medium (Balanced)',
                              'low': 'Low (Smallest Size)',
                            },
                            (val) => controller.setSelectedQuality(val),
                          ),
                          _buildDropdown(
                            'Default Audio Quality',
                            controller.selectedAudioBitrate,
                            const {
                              '96k': '96k (Low)',
                              '128k': '128k (Standard)',
                              '192k': '192k (High)',
                              '256k': '256k (Pro)',
                              '320k': '320k (Maximum)',
                              'copy': 'Passthrough (Copy Original)',
                            },
                            (val) => controller.setSelectedAudioBitrate(val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildGlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Hardware'),
                          _buildDropdown(
                            'Preferred GPU / Encoder',
                            controller.config!['force_encoder'] ?? '',
                            {
                              '': 'Auto-Detect (Best Available)',
                              for (var e in controller.availableEncoders)
                                e['video_encoder'] as String: e['label'] as String,
                            },
                            (val) => controller.setConfigValue('force_encoder', val == '' ? null : val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildGlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Support the Project'),
                          Text(
                            'If you find MKVoodoo useful, please consider supporting development! Your donations help keep the magic alive. ✨',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _buildSupportButton(
                                'Buy me a Ko-fi',
                                'https://ko-fi.com/synonimity',
                                const Color(0xFF29ABE2),
                                Icons.coffee_rounded,
                              ),
                              _buildSupportButton(
                                'PayPal',
                                'https://www.paypal.com/donate/?business=synontech.sa@gmail.com&no_recurring=0&currency_code=USD',
                                const Color(0xFF003087),
                                Icons.payment_rounded,
                              ),
                              _buildSupportButton(
                                'Patreon',
                                'https://patreon.com/SoulLink',
                                const Color(0xFFF96854),
                                Icons.favorite_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      margin: const EdgeInsets.only(bottom: 64),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB900FF), Color(0xFF7000FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB900FF).withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: controller.isSaving
                            ? null
                            : () async {
                                final success = await controller.saveSettings();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(success ? 'Settings saved successfully' : 'Failed to save settings'),
                                      backgroundColor: success ? const Color(0xFF2ECC71) : Colors.redAccent,
                                    ),
                                  );
                                }
                              },
                        icon: controller.isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_rounded),
                        label: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          minimumSize: const Size(200, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFB900FF),
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGlassPanel({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 700,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              if (isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController textController, String hint, {double? width}) {
    return Container(
      width: width ?? double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: textController,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorableField(String label, TextEditingController textController, String hint, VoidCallback onBrowse) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              Container(
                height: 52,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
                ),
                clipBehavior: Clip.antiAlias,
                child: ElevatedButton.icon(
                  onPressed: onBrowse,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Browse'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB900FF),
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, Map<String, String> options, Function(String) onChanged) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: Theme.of(context).cardColor,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                items: options.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) onChanged(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile(
          title: Text(
            title,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFFB900FF),
        ),
      ),
    );
  }

  Widget _buildThemeDropdown() {
    final themeProvider = context.watch<ThemeProvider>();
    return _buildDropdown(
      'Application Theme',
      themeProvider.themeMode.toString().split('.').last,
      const {
        'system': 'System Default',
        'light': 'Light Mode',
        'dark': 'Dark Mode',
      },
      (val) {
        ThemeMode mode;
        if (val == 'light') {
          mode = ThemeMode.light;
        } else if (val == 'dark') {
          mode = ThemeMode.dark;
        } else {
          mode = ThemeMode.system;
        }
        themeProvider.setTheme(mode);
      },
    );
  }

  Widget _buildSupportButton(String label, String url, Color color, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}
