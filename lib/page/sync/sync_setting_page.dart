/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/sync/sync_auth_service.dart';
import 'package:pixez/sync/sync_config.dart';
import 'package:pixez/sync/sync_engine.dart';

class SyncSettingPage extends StatefulWidget {
  @override
  _SyncSettingPageState createState() => _SyncSettingPageState();
}

class _SyncSettingPageState extends State<SyncSettingPage> {
  late SyncConfig syncConfig;
  final SyncAuthService _authService = SyncAuthService();
  SyncEngine? _engine;

  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoggedIn = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    syncConfig = SyncConfig();
    syncConfig.init();
    _engine = SyncEngine(syncConfig);

    syncConfig.init().then((_) {
      setState(() {
        _urlController.text = syncConfig.serverUrl;
        _usernameController.text = syncConfig.username;
        _isLoggedIn = syncConfig.token.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(I18n.of(context).sync_settings)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEnableSwitch(),
            const Divider(),
            _buildServerSection(),
            const Divider(),
            _buildAuthSection(),
            const Divider(),
            _buildStatusSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableSwitch() {
    return Observer(
      builder: (_) => SwitchListTile(
        title: Text(I18n.of(context).enable_sync),
        subtitle: Text(I18n.of(context).enable_sync_desc),
        value: syncConfig.enabled,
        onChanged: _isLoggedIn
            ? (v) => syncConfig.setEnabled(v)
            : (_) {
                BotToast.showText(
                    text: I18n.of(context).please_login_first);
              },
      ),
    );
  }

  Widget _buildServerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(I18n.of(context).server_config,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Observer(
          builder: (_) => TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: I18n.of(context).server_url,
              hintText: 'https://your-server.com',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) => syncConfig.setServerUrl(_urlController.text),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthSection() {
    if (_isLoggedIn) {
      return _buildLoggedInSection();
    }
    return _buildLoginSection();
  }

  Widget _buildLoginSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(I18n.of(context).account,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: I18n.of(context).username,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: I18n.of(context).password,
            border: const OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                child: Text(I18n.of(context).register),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text(I18n.of(context).login),
              ),
            ),
          ],
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildLoggedInSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(I18n.of(context).account,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        ListTile(
          leading: const Icon(Icons.person),
          title: Text(syncConfig.username),
          subtitle: Text(I18n.of(context).logged_in),
          trailing: TextButton(
            onPressed: _handleLogout,
            child: Text(I18n.of(context).logout,
                style: const TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(I18n.of(context).sync_status,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Observer(
          builder: (_) => Column(
            children: [
              ListTile(
                leading: const Icon(Icons.sync),
                title: Text(I18n.of(context).last_sync),
                trailing: Text(
                  syncConfig.lastSyncTimestamp > 0
                      ? _formatTimestamp(syncConfig.lastSyncTimestamp)
                      : I18n.of(context).never_synced,
                ),
              ),
              if (syncConfig.lastSyncError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    syncConfig.lastSyncError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: syncConfig.isSyncing ? null : _handleSync,
                  icon: syncConfig.isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(syncConfig.isSyncing
                      ? I18n.of(context).syncing
                      : I18n.of(context).sync_now),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleDeleteAccount,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: Text(I18n.of(context).delete_account,
                      style: const TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      BotToast.showText(text: I18n.of(context).fill_all_fields);
      return;
    }
    if (syncConfig.serverUrl.isEmpty) {
      BotToast.showText(text: I18n.of(context).server_url_required);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = await _authService.register(syncConfig, username, password);
      final token = data['token'] as String? ?? '';
      if (token.isNotEmpty) {
        await syncConfig.setCredentials(username, token);
        await syncConfig.setEnabled(true);
        setState(() => _isLoggedIn = true);
        BotToast.showText(text: I18n.of(context).register_success);
      }
    } catch (e) {
      BotToast.showText(text: '${I18n.of(context).error}: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      BotToast.showText(text: I18n.of(context).fill_all_fields);
      return;
    }
    if (syncConfig.serverUrl.isEmpty) {
      BotToast.showText(text: I18n.of(context).server_url_required);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = await _authService.login(syncConfig, username, password);
      final token = data['token'] as String? ?? '';
      if (token.isNotEmpty) {
        await syncConfig.setCredentials(username, token);
        await syncConfig.setEnabled(true);
        setState(() => _isLoggedIn = true);
        BotToast.showText(text: I18n.of(context).login_success);
      }
    } catch (e) {
      BotToast.showText(text: '${I18n.of(context).error}: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    await syncConfig.clearCredentials();
    setState(() {
      _isLoggedIn = false;
      _usernameController.clear();
      _passwordController.clear();
    });
    BotToast.showText(text: I18n.of(context).logged_out);
  }

  Future<void> _handleSync() async {
    if (!syncConfig.enabled || syncConfig.token.isEmpty) {
      BotToast.showText(text: I18n.of(context).please_enable_sync);
      return;
    }

    syncConfig.setSyncing(true);
    try {
      final pushed = await _engine!.pushAll();
      final pulled = await _engine!.pullAll();

      if (pushed && pulled) {
        BotToast.showText(text: I18n.of(context).sync_success);
      } else {
        BotToast.showText(text: I18n.of(context).sync_partial);
      }
    } catch (e) {
      BotToast.showText(text: '${I18n.of(context).error}: $e');
    } finally {
      syncConfig.setSyncing(false);
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.of(context).delete_account),
        content: Text(I18n.of(context).delete_account_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(I18n.of(context).Cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _authService.deleteAccount(syncConfig);
      await syncConfig.clearCredentials();
      setState(() {
        _isLoggedIn = false;
        _usernameController.clear();
        _passwordController.clear();
      });
      BotToast.showText(text: I18n.of(context).account_deleted);
    } catch (e) {
      BotToast.showText(text: '${I18n.of(context).error}: $e');
    }
  }

  String _formatTimestamp(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
