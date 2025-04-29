import 'package:flutter/material.dart';
import 'package:maskedrealm/supabase_client.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shimmer/shimmer.dart';
import 'paywall_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  String selectedStatus = 'Watching';
  String selectedGenre = 'Action/Adventure';
  String selectedFilterGenre = 'ALL'; // For filtering anime by genre
  int selectedRating = 3;
  final List<String> statuses = ['Watching', 'Completed', 'Dropped'];
  final List<String> genres = [
    'Action/Adventure',
    'Romance/Drama',
    'Fantasy/SciFi',
    'Comedy/Slice of Life'
  ];
  bool loading = false;
  bool isPremium = false;
  bool fetchingAnime = false;
  NativeAd? _nativeAd;
  bool _isNativeAdLoaded = false;
  List<Map<String, dynamic>> uploadedAnime = [];
  List<Map<String, dynamic>> filteredAnime = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _loadNativeAd();
    SupabaseService.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == 'SIGNED_IN') {
        await _initializeApp();
      }
    });
  }

  Future<void> _initializeApp() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user != null) {
      await _checkPremiumStatus();
      await _fetchAnimeList();
    } else {
      print('User not signed in yet.');
    }
  }

  Future<void> _checkPremiumStatus() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        final response = await SupabaseService.client
            .from('profiles')
            .select('is_premium')
            .eq('id', userId)
            .single();
        setState(() {
          isPremium = response['is_premium'] ?? false;
        });
      } catch (e) {
        await SupabaseService.client
            .from('profiles')
            .upsert({'id': userId, 'is_premium': false});
      }
    }
  }

  void _loadNativeAd() {
    if (isPremium) return;
    _nativeAd = NativeAd(
      adUnitId: 'ca-app-pub-8355736208842576/5287276226',
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isNativeAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('Failed to load native ad: ${error.message}');
        },
      ),
    )..load();
  }

  Future<void> _fetchAnimeList() async {
    setState(() => fetchingAnime = true);
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;
      final response = await SupabaseService.client
          .from('anime')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      print('Fetched Anime Data: $response');
      setState(() {
        uploadedAnime = List<Map<String, dynamic>>.from(response);
        filteredAnime = List.from(uploadedAnime);
      });
    } catch (error) {
      print('Error fetching anime: $error');
      _showError('Error fetching anime: $error');
    } finally {
      setState(() => fetchingAnime = false);
    }
  }

  void _filterAnime(String query) {
    setState(() {
      filteredAnime = uploadedAnime.where((anime) {
        final title = anime['title'].toString().toLowerCase();
        return title.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _filterByGenre(String genre) {
    setState(() {
      selectedFilterGenre = genre;
      if (genre == 'ALL') {
        filteredAnime = List.from(uploadedAnime);
      } else {
        filteredAnime =
            uploadedAnime.where((anime) => anime['genre'] == genre).toList();
      }
    });
  }

  Future<String?> _fetchAnimePoster(String title) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.jikan.moe/v4/anime?q=${Uri.encodeComponent(title)}&limit=1'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          return data['data'][0]['images']?['jpg']?['image_url'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching anime poster: $e');
      return null;
    }
  }

  Future<void> addAnime() async {
    if (titleController.text.isEmpty) {
      _showError('Please enter anime title');
      return;
    }
    setState(() => loading = true);
    try {
      final posterUrl = await _fetchAnimePoster(titleController.text.trim());
      if (posterUrl == null) {
        _showError('Could not find anime poster');
        return;
      }
      final userId = SupabaseService.client.auth.currentUser!.id;
      final newAnime = {
        'title': titleController.text.trim(),
        'status': selectedStatus,
        'genre': selectedGenre,
        'poster_url': posterUrl,
        'user_id': userId,
        'rating': selectedRating,
      };
      print('Inserting Anime: $newAnime');
      await SupabaseService.client.from('anime').insert(newAnime);
      await _fetchAnimeList();
      _resetForm();
    } catch (error) {
      print('Error adding anime: $error');
      _showError('Failed to add anime: $error');
    } finally {
      setState(() => loading = false);
    }
  }

  void _resetForm() {
    titleController.clear();
    searchController.clear();
    setState(() {
      selectedStatus = 'Watching';
      selectedGenre = 'Action/Adventure';
      selectedRating = 3;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => PaywallDialog(
        onPurchaseSuccess: () async {
          await _checkPremiumStatus();
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _cycleStatus(int index) async {
    final anime = filteredAnime[index];
    final currentStatus = anime['status'];
    final nextStatusIndex =
        (statuses.indexOf(currentStatus) + 1) % statuses.length;
    final newStatus = statuses[nextStatusIndex];
    setState(() {
      filteredAnime[index]['status'] = newStatus;
    });
    try {
      await SupabaseService.client.from('anime').update({
        'status': newStatus,
      }).eq('id', anime['id']);
    } catch (error) {
      _showError('Failed to update status: $error');
    }
  }

  Future<void> _deleteAnime(int index) async {
    final anime = filteredAnime[index];
    try {
      await SupabaseService.client.from('anime').delete().eq('id', anime['id']);
      setState(() {
        filteredAnime.removeAt(index);
        uploadedAnime.removeWhere((item) => item['id'] == anime['id']);
      });
    } catch (error) {
      _showError('Failed to delete anime: $error');
    }
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    titleController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Masked Realm',
          style: GoogleFonts.roboto(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.black.withOpacity(0.7),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.red),
        toolbarHeight: 80,
        actions: [
          IconButton(
            icon: Icon(isPremium ? Icons.verified : Icons.star,
                color: isPremium ? Colors.blue : Colors.amber),
            onPressed: isPremium ? null : _showPremiumDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await SupabaseService.client.auth.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchAnimeList,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              _buildAddAnimeForm(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: fetchingAnime
                              ? _buildLoadingShimmer()
                              : _buildAnimeCollection(),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAnimeForm() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Anime',
            style: GoogleFonts.roboto(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            style: GoogleFonts.roboto(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Anime Title',
              labelStyle: GoogleFonts.roboto(fontSize: 14, color: Colors.red),
              filled: true,
              fillColor: Colors.black.withOpacity(0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child:
                    _buildDropdown('Status', selectedStatus, statuses, (value) {
                  setState(() => selectedStatus = value!);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown('Genre', selectedGenre, genres, (value) {
                  setState(() => selectedGenre = value!);
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRatingBar(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: addAnime,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: loading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Add Anime',
                    style:
                        GoogleFonts.roboto(fontSize: 16, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeCollection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            onChanged: _filterAnime,
            style: GoogleFonts.roboto(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Search Anime',
              labelStyle: GoogleFonts.roboto(fontSize: 14, color: Colors.white),
              prefixIcon: const Icon(Icons.search, color: Colors.red),
              filled: true,
              fillColor: Colors.black.withOpacity(0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...['ALL', ...genres].map((genre) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton(
                        onPressed: () => _filterByGenre(genre),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: genre == selectedFilterGenre
                              ? Colors.red
                              : Colors.grey[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          genre,
                          style: GoogleFonts.roboto(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (filteredAnime.isEmpty)
            _buildEmptyState()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemCount: filteredAnime.length,
              itemBuilder: (context, index) {
                return _buildAnimeItem(filteredAnime[index], index);
              },
            ),
          if (_isNativeAdLoaded && !isPremium)
            Container(
              height: 100,
              margin: const EdgeInsets.only(top: 12),
              child: AdWidget(ad: _nativeAd!),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.grey[900],
      style: GoogleFonts.roboto(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.roboto(fontSize: 14, color: Colors.red),
        filled: true,
        fillColor: Colors.black.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item, style: GoogleFonts.roboto()),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildRatingBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rating:',
          style: GoogleFonts.roboto(color: Colors.white),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return IconButton(
              icon: Icon(
                index < selectedRating ? Icons.star : Icons.star_border,
                color: Colors.red,
                size: 28,
              ),
              onPressed: () {
                setState(() => selectedRating = index + 1);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildLoadingShimmer() {
    return Column(
      children: List.generate(4, (index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[800]!,
          highlightColor: Colors.grey[600]!,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(Icons.movie_filter, size: 50, color: Colors.white54),
          const SizedBox(height: 16),
          Text(
            'Your anime collection is empty',
            style: GoogleFonts.roboto(fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some anime using the form above!',
            style: GoogleFonts.roboto(fontSize: 14, color: Colors.white54),
          ),
          if (_isNativeAdLoaded && !isPremium)
            Container(
              height: 100,
              margin: const EdgeInsets.only(top: 16),
              child: AdWidget(ad: _nativeAd!),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimeItem(Map<String, dynamic> anime, int index) {
    return Card(
      color: Colors.black.withOpacity(0.5),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              anime['poster_url'],
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[800],
                  child: const Center(
                      child: CircularProgressIndicator(color: Colors.red)),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[800],
                  child: const Center(
                      child: Icon(Icons.movie_filter, color: Colors.red)),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime['title'],
                    style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${anime['status']} â€¢ ${anime['genre']}',
                    style:
                        GoogleFonts.roboto(color: Colors.white54, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(5, (starIndex) {
                      return Icon(
                        Icons.star,
                        size: 15,
                        color: starIndex < (anime['rating'] ?? 3)
                            ? Colors.red
                            : Colors.grey,
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: ElevatedButton(
                          onPressed: () => _cycleStatus(index),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black38,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            textStyle: GoogleFonts.roboto(fontSize: 14),
                          ),
                          child: Text(
                            'Status',
                            style: GoogleFonts.roboto(
                                fontSize: 15, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: ElevatedButton(
                          onPressed: () => _deleteAnime(index),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black45,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Delete',
                            style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: const Color.fromARGB(255, 255, 75, 75)),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
