import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'Welcome to AstraPlay',
      description: 'Your premium IPTV streaming experience starts here. Beautifully designed and easy to use.',
      icon: Icons.auto_awesome_rounded,
      color: Colors.blue,
    ),
    OnboardingItem(
      title: 'Global Content',
      description: 'Stream live TV, movies, and series from all over the world. Organize your playlists with ease.',
      icon: Icons.movie_filter_rounded,
      color: Colors.orange,
    ),
    OnboardingItem(
      title: 'Powerful Player',
      description: 'Enjoy high-quality streaming with our optimized player featuring gesture controls and subtitle support.',
      icon: Icons.play_circle_filled_rounded,
      color: Colors.purple,
    ),
    OnboardingItem(
      title: 'Ready to Start?',
      description: 'Add your first playlist and start exploring your favorite content now.',
      icon: Icons.rocket_launch_rounded,
      color: Colors.teal,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _items.length,
            itemBuilder: (context, index) => _OnboardingView(item: _items[index]),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(
                    _items.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 8),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                if (_currentPage == _items.length - 1)
                  FilledButton.icon(
                    onPressed: _completeOnboarding,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Get Started'),
                  ).animate().scale().fadeIn()
                else
                  IconButton.filled(
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    },
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _OnboardingView extends StatelessWidget {
  final OnboardingItem item;

  const _OnboardingView({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              size: 100,
              color: item.color,
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).fadeIn(),
          const SizedBox(height: 48),
          Text(
            item.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            textAlign: TextAlign.center,
          ).animate().slideY(begin: 0.2, end: 0).fadeIn(delay: 200.ms),
          const SizedBox(height: 16),
          Text(
            item.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ).animate().slideY(begin: 0.2, end: 0).fadeIn(delay: 400.ms),
        ],
      ),
    );
  }
}
