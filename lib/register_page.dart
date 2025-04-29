import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'package:maskedrealm/supabase_client.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool loading = false;
  bool acceptPolicy = false;
  bool showPolicy = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!acceptPolicy) {
      showError('You must accept the Privacy Policy to register.');
      return;
    }
    if (passwordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      showError('Passwords do not match!');
      return;
    }

    setState(() => loading = true);

    try {
      final response = await SupabaseService.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      if (response.user != null) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const Dashboard()));
      } else {
        showError('Failed to register. Try again.');
      }
    } catch (error) {
      showError('Error: ${error.toString()}');
    }

    setState(() => loading = false);
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.7)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
      ),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/bg.jpg',
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.black.withOpacity(0.6),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Register",
                          style: TextStyle(
                            color: Color.fromARGB(255, 255, 0, 0),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          controller: emailController,
                          decoration: _inputDecoration('Email'),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Enter email';
                            if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$")
                                .hasMatch(value)) {
                              return 'Enter valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          controller: passwordController,
                          obscureText: true,
                          decoration: _inputDecoration('Password'),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Enter password';
                            if (value.length < 6) return 'Minimum 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          controller: confirmPasswordController,
                          obscureText: true,
                          decoration: _inputDecoration('Confirm Password'),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Confirm password';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Checkbox(
                              value: acceptPolicy,
                              activeColor: Colors.red,
                              onChanged: (value) {
                                setState(() {
                                  acceptPolicy = value ?? false;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "I accept the Privacy Policy",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              showPolicy = !showPolicy;
                            });
                          },
                          child: Text(
                            showPolicy ? "Hide Policy" : "View Policy",
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        if (showPolicy) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "• By using this app,your provided data (email,password) \n"
                              "• We Uses Third Party Cloud Storage To Store the info\n "
                              "• And It Will Not Shared Into Public Or Any Other Third Parties\n",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (loading)
                          const CircularProgressIndicator(
                              color: Color.fromARGB(255, 255, 0, 0))
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 255, 0, 0),
                              minimumSize: const Size.fromHeight(50),
                            ),
                            onPressed: register,
                            child: const Text('Register',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
