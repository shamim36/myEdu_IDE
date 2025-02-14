import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyEdu IDE v4',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CodeEditorScreen(),
    );
  }
}

class HackerEarthService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.hackerearth.com/v4/partner/code-evaluation/',
    headers: {
      'client-secret': 'd3139107cbc9a314523e000c3c1b363fcc6fbe79',
      'Content-Type': 'application/json',
    },
  ));

  Future<Map<String, dynamic>> submitCode({
    required String source,
    required String lang,
    String input = '',
    int memoryLimit = 262144,
    int timeLimit = 5,
  }) async {
    try {
      final response = await _dio.post(
        'submissions/',
        data: {
          'lang': lang,
          'source': source,
          'input': input,
          'memory_limit': memoryLimit,
          'time_limit': timeLimit,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception('Submission failed: ${e.response?.data ?? e.message}');
    }
  }

  Future<Map<String, dynamic>> getStatus(String heId) async {
    try {
      final response = await _dio.get('submissions/$heId/');
      return response.data;
    } on DioException catch (e) {
      throw Exception('Status check failed: ${e.response?.data ?? e.message}');
    }
  }

  Future<String> fetchOutput(String url) async {
    try {
      final response = await Dio().get(url);
      return response.data;
    } catch (e) {
      return 'Failed to fetch output: $e';
    }
  }
}

class CodeEditorScreen extends StatefulWidget {
  const CodeEditorScreen({super.key});

  @override
  State<CodeEditorScreen> createState() => _CodeEditorScreenState();
}

class _CodeEditorScreenState extends State<CodeEditorScreen> {
  final HackerEarthService _service = HackerEarthService();
  final List<String> _languages = [
    'PYTHON',
    'PYTHON3',
    'CPP14',
    'CPP17',
    'JAVA8',
    'JAVA14',
    'JAVASCRIPT_NODE',
    'CSHARP',
    'GO',
    'RUST',
    'SWIFT'
  ];
  String _selectedLang = 'PYTHON3';
  String _sourceCode = '';
  String _input = '';
  String _output = '';
  String _status = '';
  String _errors = '';
  bool _isLoading = false;
  String? _heId;
  Timer? _pollTimer;

  void _submitCode() async {
    if (_sourceCode.isEmpty) {
      _showError('Please write some code first');
      return;
    }

    setState(() {
      _isLoading = true;
      _errors = '';
      _output = '';
      _status = 'Submitting...';
    });

    try {
      final response = await _service.submitCode(
        source: _sourceCode,
        lang: _selectedLang,
        input: _input,
      );

      _heId = response['he_id'];
      if (_heId == null) throw Exception('No HE ID received');

      _startPolling();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_heId == null) {
        timer.cancel();
        return;
      }

      try {
        final statusResponse = await _service.getStatus(_heId!);
        final statusCode = statusResponse['request_status']['code'];

        setState(() => _status = statusResponse['request_status']['message']);

        if (statusCode == 'REQUEST_COMPLETED') {
          timer.cancel();
          _handleCompletedRequest(statusResponse);
        } else if (statusCode == 'REQUEST_FAILED') {
          timer.cancel();
          _showError('Request failed');
        }
      } catch (e) {
        timer.cancel();
        _showError(e.toString());
      }
    });
  }

  void _handleCompletedRequest(Map<String, dynamic> response) async {
    final compileStatus = response['result']['compile_status'];
    final runStatus = response['result']['run_status'];

    if (compileStatus != 'OK') {
      setState(() => _errors = 'Compilation Error: $compileStatus');
      return;
    }

    if (runStatus['status'] != 'AC') {
      setState(() => _errors = 'Runtime Error: ${runStatus['status_detail']}');
      return;
    }

    if (runStatus['output'] != null) {
      final outputUrl = runStatus['output'];
      final output = await _service.fetchOutput(outputUrl);
      setState(() => _output = output);
    }

    setState(() => _isLoading = false);
  }

  void _showError(String message) {
    setState(() {
      _errors = message;
      _isLoading = false;
      _pollTimer?.cancel();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MyEdu IDE v4')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedLang,
                    items: _languages
                        .map((lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(lang),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedLang = value!),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitCode,
                  child: const Text('Run Code'),
                ),
              ],
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Code Editor',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: TextField(
                            maxLines: null,
                            expands: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Enter your code here...',
                            ),
                            onChanged: (value) => _sourceCode = value,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Input',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: TextField(
                            maxLines: null,
                            expands: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Enter input...',
                            ),
                            onChanged: (value) => _input = value,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading) ...[
              LinearProgressIndicator(value: null),
              Expanded(
                  child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text("id : $_heId",
                        style: const TextStyle(color: Colors.blue)),
                    Text("Status : $_status",
                        style: const TextStyle(color: Colors.blue)),
                  ],
                ),
              ))
            ],
            if (_errors.isNotEmpty)
              Text(_errors, style: const TextStyle(color: Colors.red)),
            if (_output.isNotEmpty) ...[
              const Text('Output:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text("id : $_heId",
                          style: const TextStyle(color: Colors.black54)),
                      Text("Status : $_status",
                          style: const TextStyle(color: Colors.green)),
                      Text("Output: ",
                          style: const TextStyle(color: Colors.black)),
                      Text(_output, style: const TextStyle(color: Colors.blue)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
