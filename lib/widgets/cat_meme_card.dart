import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/cat_meme_model.dart';
import '../../services/cat_meme_service.dart';

class CatMemeCard extends StatefulWidget {
  const CatMemeCard({super.key});

  @override
  State<CatMemeCard> createState() => _CatMemeCardState();
}

class _CatMemeCardState extends State<CatMemeCard>
    with SingleTickerProviderStateMixin {
  CatMeme? _meme;
  bool _loading = true;
  bool _dismissed = false;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  // Cute loading messages while fetching
  static const _loadingQuips = [
    'Fetching a cat from the internet... 🐱',
    'Bribing a cat with treats... 🍗',
    'The cat is thinking about it... 🤔',
    'Waking up a sleeping cat... 😴',
  ];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnim = CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    );
    _loadMeme();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  Future<void> _loadMeme() async {
    setState(() => _loading = true);
    final meme = await CatMemeService.instance.getNextMeme();
    if (!mounted) return;
    setState(() {
      _meme = meme;
      _loading = false;
    });
    _bounceController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ScaleTransition(
      scale: _bounceAnim,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.primary.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text('😺', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'Daily Cat Meme',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  // Refresh button
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: colorScheme.onSurface.withOpacity(0.4),
                    onPressed: _loadMeme,
                    tooltip: 'Next cat',
                  ),
                  const SizedBox(width: 8),
                  // Dismiss button
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: colorScheme.onSurface.withOpacity(0.4),
                    onPressed: () => setState(() => _dismissed = true),
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
            ),

            // Image area
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: _loading
                  ? _buildLoadingState(theme, colorScheme)
                  : _meme == null
                      ? _buildErrorState(theme, colorScheme)
                      : _buildMemeImage(theme, colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, ColorScheme colorScheme) {
    final quip =
        _loadingQuips[DateTime.now().second % _loadingQuips.length];
    return Container(
      height: 200,
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            quip,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      height: 160,
      color: colorScheme.surfaceVariant.withOpacity(0.2),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😿', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              'The cat escaped... try again?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadMeme, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildMemeImage(ThemeData theme, ColorScheme colorScheme) {
    return Stack(
      children: [
        CachedNetworkImage(
          imageUrl: _meme!.imageUrl,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            height: 220,
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 160,
            color: colorScheme.surfaceVariant.withOpacity(0.2),
            child: const Center(
              child: Text('😿', style: TextStyle(fontSize: 40)),
            ),
          ),
        ),
        // Caption overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _meme!.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_upward,
                    size: 12, color: Colors.orange),
                const SizedBox(width: 2),
                Text(
                  '${_meme!.upvotes}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
