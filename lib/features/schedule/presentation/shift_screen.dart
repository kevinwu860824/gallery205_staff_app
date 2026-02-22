import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  String? _selectedMonth;
  String? _imageUrl;
  File? _imageFile;
  String? _userRole;
  String? _shopId;
  bool _showUploadPanel = false;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
  final prefs = await SharedPreferences.getInstance();
  
  // ✅ 步驟一：像 HomeScreen 一樣，使用 currentSession
  final session = Supabase.instance.client.auth.currentSession;
  final userId = session?.user.id;
  _shopId = prefs.getString('savedShopId');

  // ✅ 步驟二：檢查 userId 而不是 user
  if (_shopId == null || userId == null) {
    if (mounted) context.go('/'); // 踢回登入頁
    return;
  }

  // ✅ 步驟三：使用 userId 進行查詢
  final userData = await Supabase.instance.client
      .from('users')
      .select('role')
      .eq('shop_id', _shopId!)
      .eq('user_id', userId) // <-- 之前這裡是 user!.id，現在更安全
      .maybeSingle();

  setState(() {
    _userRole = userData?['role'];
    _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  });

  _loadImageForMonth(_selectedMonth!);
}

  List<String> _getMonthOptions() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM');
    return List.generate(7, (i) {
      final date = DateTime(now.year, now.month - 3 + i);
      return formatter.format(date);
    });
  }

  Future<void> _loadImageForMonth(String monthStr) async {
  if (_shopId == null) return;

  setState(() => _imageUrl = null); // 清掉舊圖片

  final parts = monthStr.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);

  final res = await Supabase.instance.client
      .from('shift_schedules')
      .select('image_url')
      .eq('shop_id', _shopId!)
      .eq('year', year)
      .eq('month', month)
      .maybeSingle();

  setState(() {
    _imageUrl = res?['image_url'];
  });
}



  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null || _selectedMonth == null || _shopId == null) return;

    final parts = _selectedMonth!.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final fileName = '${_shopId}_$year-$month.jpg';
    final storage = Supabase.instance.client.storage;

    final fileBytes = await _imageFile!.readAsBytes();

    await storage.from('schedules').uploadBinary(
      fileName,
      fileBytes,
      fileOptions: const FileOptions(upsert: true),
    );

    final url = storage.from('schedules').getPublicUrl(fileName);

    final exists = await Supabase.instance.client
        .from('shift_schedules')
        .select('id')
        .eq('shop_id', _shopId!)
        .eq('year', year)
        .eq('month', month)
        .maybeSingle();

    if (exists != null) {
      await Supabase.instance.client
          .from('shift_schedules')
          .update({'image_url': url})
          .eq('id', exists['id']);
    } else {
      await Supabase.instance.client.from('shift_schedules').insert({
        'shop_id': _shopId,
        'year': year,
        'month': month,
        'image_url': url,
      });
    }

    setState(() {
      _imageUrl = url;
      _imageFile = null;
      _showUploadPanel = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canUpload = _userRole == 'admin' || _userRole == 'manager';

    return Scaffold(
      appBar: AppBar(
        title: const Text('班表'),
        actions: [
          if (canUpload)
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: () {
                setState(() {
                  _showUploadPanel = !_showUploadPanel;
                });
              },
            )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          DropdownButton<String>(
            value: _selectedMonth,
            items: _getMonthOptions()
                .map((month) => DropdownMenuItem(value: month, child: Text(month)))
                .toList(),
            onChanged: (value) async {
  if (value != null) {
    setState(() {
      _selectedMonth = value;
    });
    await _loadImageForMonth(value);
  }
},

          ),
          if (_imageUrl != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: InteractiveViewer(
                  child: Image.network(_imageUrl!, fit: BoxFit.contain),
                ),
              ),
            )
          else
            const Expanded(child: Center(child: Text('尚未上傳班表'))),

          if (canUpload && _showUploadPanel) ...[
            const Divider(),
            const Text('上傳班表', style: TextStyle(fontWeight: FontWeight.bold)),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('選擇圖片'),
            ),
            if (_imageFile != null)
              Text('已選擇：${_imageFile!.path.split("/").last}'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _uploadImage,
              child: const Text('上傳'),
            ),
            const SizedBox(height: 20),
          ]
        ],
      ),
    );
  }
}
