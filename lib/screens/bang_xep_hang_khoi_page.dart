import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/nhan_xet_service.dart';
import '../l10n/app_localizations.dart';

class BangXepHangKhoiPage extends StatefulWidget {
  const BangXepHangKhoiPage({super.key});

  @override
  State<BangXepHangKhoiPage> createState() => _BangXepHangKhoiPageState();
}

class _BangXepHangKhoiPageState extends State<BangXepHangKhoiPage> with SingleTickerProviderStateMixin {
  final NhanXetService _nhanXetService = NhanXetService();
  late TabController _gradeTabController;
  final List<int> _grades = [6, 7, 8, 9, 10, 11, 12];
  
  // Months list for dropdown (current month and previous 2 months)
  late List<String> _months;
  late String _selectedMonth;

  // Theme design
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color cardColor = Color(0xFF16213E);
  static const Color lightText = Colors.white;
  static const Color secondaryText = Colors.white70;
  static const Color accentColor = Color(0xFF00BFA5);

  @override
  void initState() {
    super.initState();
    _gradeTabController = TabController(length: _grades.length, vsync: this);
    
    // Generate months list (YYYY-MM)
    final now = DateTime.now();
    _months = List.generate(3, (index) {
      final date = DateTime(now.year, now.month - index, 1);
      return DateFormat('yyyy-MM').format(date);
    });
    _selectedMonth = _months.first;
  }

  @override
  void dispose() {
    _gradeTabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getRankUiData(String rank) {
    switch (rank) {
      case 'Thách Đấu':
        return {
          'color': Colors.redAccent, 
          'icon': Icons.local_fire_department, 
          'badgeColor': Colors.red.shade900
        };
      case 'Cao Thủ':
        return {
          'color': Colors.orangeAccent, 
          'icon': Icons.military_tech, 
          'badgeColor': Colors.amber.shade900
        };
      case 'Tinh Anh':
        return {
          'color': Colors.purpleAccent, 
          'icon': Icons.auto_awesome, 
          'badgeColor': Colors.purple.shade900
        };
      case 'Kim Cương':
        return {
          'color': Colors.cyanAccent, 
          'icon': Icons.diamond, 
          'badgeColor': Colors.cyan.shade900
        };
      case 'Bạch Kim':
        return {
          'color': Colors.grey.shade300, 
          'icon': Icons.shield, 
          'badgeColor': Colors.grey.shade700
        };
      case 'Vàng':
        return {
          'color': Colors.amberAccent, 
          'icon': Icons.star, 
          'badgeColor': Colors.yellow.shade800
        };
      case 'Bạc':
        return {
          'color': Colors.blueGrey.shade300, 
          'icon': Icons.verified, 
          'badgeColor': Colors.blueGrey.shade700
        };
      default: // 'Đồng'
        return {
          'color': Colors.brown.shade300, 
          'icon': Icons.workspace_premium, 
          'badgeColor': Colors.brown.shade700
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        title: Text(isVi ? 'ĐẤU TRƯỜNG HẠNG KHỐI' : 'GRADE LEADERBOARDS'),
        centerTitle: true,
        backgroundColor: cardColor,
        foregroundColor: lightText,
        actions: [
          // Month Selector Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: darkBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentColor.withOpacity(0.5)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedMonth,
                dropdownColor: cardColor,
                icon: const Icon(Icons.arrow_drop_down, color: accentColor),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedMonth = newValue;
                    });
                  }
                },
                items: _months.map<DropdownMenuItem<String>>((String value) {
                  final parts = value.split('-');
                  final displayVal = parts.length == 2 ? '${parts[1]}/${parts[0]}' : value;
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      displayVal,
                      style: const TextStyle(color: lightText, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _gradeTabController,
          indicatorColor: accentColor,
          labelColor: accentColor,
          unselectedLabelColor: secondaryText,
          isScrollable: true,
          tabs: _grades.map((g) => Tab(text: isVi ? 'Khối $g' : 'Grade $g')).toList(),
        ),
      ),
      body: TabBarView(
        controller: _gradeTabController,
        children: _grades.map((grade) => _buildGradeLeaderboard(grade)).toList(),
      ),
    );
  }

  Widget _buildGradeLeaderboard(int grade) {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _nhanXetService.layBangXepHangTheoKhoi(grade, _selectedMonth),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: accentColor));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              isVi ? 'Lỗi: ${snapshot.error}' : 'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final students = snapshot.data ?? [];
        if (students.isEmpty) {
          return Center(
            child: Text(
              isVi ? 'Chưa có dữ liệu xếp hạng khối này.' : 'No ranking data for this grade.',
              style: const TextStyle(color: secondaryText),
            ),
          );
        }

        return Column(
          children: [
            // Top 3 Header layout (gamified)
            if (students.length >= 3) _buildTopThreePodium(students.take(3).toList()),
            
            // Remaining list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  // Skip top 3 if we displayed podium, or display all in normal list
                  if (students.length >= 3 && index < 3) return const SizedBox.shrink();
                  
                  final student = students[index];
                  final int rankPos = index + 1;
                  final String rankName = student['xep_hang'] ?? 'Đồng';
                  final rankUi = _getRankUiData(rankName);
                  final double avg = student['diem_trung_binh'] ?? 0.0;

                  return Card(
                    color: cardColor,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$rankPos',
                          style: const TextStyle(color: lightText, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        student['ten_hoc_sinh'] ?? '',
                        style: const TextStyle(color: lightText, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${student['ten_lop']} • ${isVi ? 'ĐTB' : 'Avg'}: ${avg.toStringAsFixed(2)}',
                        style: const TextStyle(color: secondaryText, fontSize: 13),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (rankUi['color'] as Color).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: (rankUi['color'] as Color).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(rankUi['icon'], color: rankUi['color'], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              rankName,
                              style: TextStyle(color: rankUi['color'], fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopThreePodium(List<Map<String, dynamic>> topThree) {
    // topThree is sorted: index 0 (1st), index 1 (2nd), index 2 (3rd)
    final first = topThree[0];
    final second = topThree[1];
    final third = topThree[2];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.5),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          _buildPodiumColumn(second, 2, 80, Colors.grey.shade400, '2'),
          // 1st Place
          _buildPodiumColumn(first, 1, 100, Colors.amberAccent, '1'),
          // 3rd Place
          _buildPodiumColumn(third, 3, 70, Colors.orangeAccent.shade400, '3'),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(Map<String, dynamic> student, int position, double height, Color accent, String numberStr) {
    final String rankName = student['xep_hang'] ?? 'Đồng';
    final rankUi = _getRankUiData(rankName);
    final double avg = student['diem_trung_binh'] ?? 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar stack with crown/rank icon
        Stack(
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: CircleAvatar(
                radius: position == 1 ? 36 : 28,
                backgroundColor: accent.withOpacity(0.2),
                child: CircleAvatar(
                  radius: position == 1 ? 32 : 25,
                  backgroundColor: cardColor,
                  child: Icon(rankUi['icon'], color: rankUi['color'], size: position == 1 ? 32 : 24),
                ),
              ),
            ),
            if (position == 1)
              const Positioned(
                top: -4,
                child: Icon(Icons.workspace_premium, color: Colors.amberAccent, size: 24),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Student details
        Container(
          constraints: const BoxConstraints(maxWidth: 95),
          child: Text(
            student['ten_hoc_sinh'] ?? '',
            style: TextStyle(
              color: lightText, 
              fontWeight: FontWeight.bold, 
              fontSize: position == 1 ? 14 : 12
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          student['ten_lop'] ?? '',
          style: const TextStyle(color: secondaryText, fontSize: 11),
        ),
        const SizedBox(height: 6),
        // Podium block
        Container(
          width: 75,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withOpacity(0.8), accent.withOpacity(0.3)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                numberStr,
                style: const TextStyle(color: darkBackground, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              Text(
                avg.toStringAsFixed(2),
                style: const TextStyle(color: darkBackground, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
