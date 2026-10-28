import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignup = false;
  final _formKey = GlobalKey<FormState>();

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String? _errorMsg;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _companyNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMsg = null);
    final appState = context.read<AppState>();
    try {
      if (_isSignup) {
        await appState.signup(
          companyName: _companyNameCtrl.text.trim(),
          username: _usernameCtrl.text.trim(),
          password: _passwordCtrl.text,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
        );
      } else {
        await appState.login(
          _usernameCtrl.text.trim(),
          _passwordCtrl.text,
        );
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _openServerConfigDialog() {
    final ctrl = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('სერვერის მისამართი (API URL)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                hintText: 'http://127.0.0.1:8000',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('PythonAnywhere (ლაივ სერვერი)'),
                  onPressed: () =>
                      ctrl.text = 'https://achi717.pythonanywhere.com',
                ),
                ActionChip(
                  label: const Text('Local (127.0.0.1:8000)'),
                  onPressed: () => ctrl.text = 'http://127.0.0.1:8000',
                ),
                ActionChip(
                  label: const Text('Android Emulator (10.0.2.2)'),
                  onPressed: () => ctrl.text = 'http://10.0.2.2:8000',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('გაუქმება'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiService.setBaseUrl(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
            child: const Text('შენახვა'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: ImpostiColors.bodyBg,
      appBar: AppBar(
        backgroundColor: ImpostiColors.sidebarBg,
        title: const ImpostiLogo(height: 34),
        actions: [
          IconButton(
            tooltip: 'სერვერის პარამეტრები',
            onPressed: _openServerConfigDialog,
            icon: const Icon(Icons.dns_outlined),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 24,
                    ),
                    color: _isSignup
                        ? ImpostiColors.sidebarBg
                        : ImpostiColors.primary,
                    child: Column(
                      children: [
                        const ImpostiLogo(height: 52, showText: false),
                        const SizedBox(height: 10),
                        Text(
                          _isSignup
                              ? 'სააგენტოს რეგისტრაცია'
                              : 'IMPOSTI — სისტემაში შესვლა',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_errorMsg != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ImpostiColors.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: ImpostiColors.danger.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: ImpostiColors.danger,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMsg!,
                                      style: const TextStyle(
                                        color: ImpostiColors.danger,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_isSignup) ...[
                            const Text(
                              'კომპანიის მონაცემები',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: ImpostiColors.secondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _companyNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'სერვის-კომპანიის (სააგენტოს) სახელი *',
                                prefixIcon: Icon(Icons.business),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'შეიყვანეთ სააგენტოს სახელი'
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'მენეჯერის (ადმინისტრატორის) მონაცემები',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: ImpostiColors.secondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstNameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'სახელი',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lastNameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'გვარი',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'ტელეფონის ნომერი',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: _usernameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'მომხმარებელი (Username) *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'შეიყვანეთ მომხმარებელი'
                                    : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'პაროლი *',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (v) =>
                                (v == null || v.isEmpty)
                                    ? 'შეიყვანეთ პაროლი'
                                    : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: appState.isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSignup
                                  ? ImpostiColors.success
                                  : ImpostiColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: appState.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isSignup ? 'რეგისტრაცია' : 'შესვლა',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isSignup = !_isSignup;
                                _errorMsg = null;
                              });
                            },
                            child: Text(
                              _isSignup
                                  ? 'უკვე გაქვთ ანგარიში? შესვლა'
                                  : 'არ გაქვთ ანგარიში? დაარეგისტრირეთ სააგენტო',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
