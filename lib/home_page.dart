
import 'package:flutter/material.dart';
import 'package:summarize_it/model/user.dart';
import 'package:summarize_it/profile_page.dart';
import 'package:summarize_it/quiz_page.dart';
import 'package:summarize_it/saved_summaries.dart';
import 'package:summarize_it/summarize_page.dart';
import 'package:water_drop_nav_bar/water_drop_nav_bar.dart';

class HomePage extends StatefulWidget {
  final User user;

  const HomePage({Key? key, required this.user}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  List<Widget> get _pages => [
    SummarizePage(user: widget.user),
    QuizPage(user: widget.user),
    SavedSummariesPage(user: widget.user),
    ProfilePage(
      user: widget.user,
      onLogout: () {
        Navigator.of(context).pushReplacementNamed('/login');
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: WaterDropNavBar(
        backgroundColor: Colors.deepPurple,
        waterDropColor: Colors.white,
        selectedIndex: _selectedIndex,
        onItemSelected: (index) => setState(() => _selectedIndex = index),
        barItems: [
          BarItem(
            filledIcon: Icons.summarize,
            outlinedIcon: Icons.summarize_outlined,
          ),
          BarItem(
            filledIcon: Icons.quiz,
            outlinedIcon: Icons.quiz_outlined,
          ),
          BarItem(
            filledIcon: Icons.collections_bookmark,
            outlinedIcon: Icons.collections_bookmark_outlined,
          ),
          BarItem(
            filledIcon: Icons.person,
            outlinedIcon: Icons.person_outline,
          ),
        ],
      ),
    );
  }
}
