import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Settings'),
                backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
                automaticallyImplyLeading: false,
                floating: true,
                snap: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Dark Mode Section
                    _buildSectionCard(
                      context,
                      'Appearance',
                      [
                        _buildDarkModeSwitch(context, themeProvider),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Theme Color Section
                    _buildSectionCard(
                      context,
                      'Theme Color',
                      [
                        _buildColorPicker(context, themeProvider),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // App Info Section
                    _buildSectionCard(
                      context,
                      'About',
                      [
                        _buildInfoTile(
                          context,
                          'App Name',
                          'QR Generator',
                          Icons.info_outline,
                        ),
                        _buildInfoTile(
                          context,
                          'Version',
                          '1.0.0',
                          Icons.code,
                        ),
                        _buildInfoTile(
                          context,
                          'Theme',
                          '${themeProvider.getColorName(themeProvider.primaryColor)} ${themeProvider.isDarkMode ? '(Dark)' : '(Light)'}',
                          Icons.palette,
                        ),
                      ],
                    ),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard(BuildContext context, String title, List<Widget> children) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDarkModeSwitch(BuildContext context, ThemeProvider themeProvider) {
    return ListTile(
      leading: Icon(
        themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text('Dark Mode'),
      subtitle: Text(
        themeProvider.isDarkMode ? 'Dark theme enabled' : 'Light theme enabled',
      ),
      trailing: Switch.adaptive(
        value: themeProvider.isDarkMode,
        onChanged: (value) {
          themeProvider.toggleDarkMode();
        },
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildColorPicker(BuildContext context, ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(
            Icons.palette,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('Choose Theme Color'),
          subtitle: Text(
            'Current: ${themeProvider.getColorName(themeProvider.primaryColor)}',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ThemeProvider.availableColors.asMap().entries.map((entry) {
              final color = entry.value;
              final name = ThemeProvider.colorNames[entry.key];
              final isSelected = themeProvider.primaryColor == color;
              
              return GestureDetector(
                onTap: () {
                  themeProvider.setPrimaryColor(color);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Theme changed to $name'),
                      duration: const Duration(seconds: 1),
                      backgroundColor: color,
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected 
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: isSelected
                    ? Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      )
                    : null,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildInfoTile(BuildContext context, String title, String value, IconData icon) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(title),
      subtitle: Text(value),
    );
  }
}
