import 'package:flutter/material.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;
  final String title;
  final String content;
  final String author;
  final String dateText;

  const PostDetailPage({
    super.key,
    required this.postId,
    required this.title,
    required this.content,
    required this.author,
    required this.dateText,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  int likes = 0;
  int dislikes = 0;

  // Firestore, Auth 제거 후 isLoading 필요 없음
  @override
  void initState() {
    super.initState();
    // 원래는 서버에서 데이터를 불러왔지만 이제는 초기값 그대로 둠
  }

  void _updateLikeDislike(bool isLike) {
    setState(() {
      if (isLike) {
        likes++;
      } else {
        dislikes++;
      }
    });
    // 더 이상 서버로 업데이트하지 않음
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.content,
                      style: const TextStyle(fontSize: 18, height: 1.6),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        const Icon(
                          Icons.edit,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '작성자: ${widget.author}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '작성일: ${widget.dateText}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _updateLikeDislike(true),
                  icon: const Icon(Icons.thumb_up, size: 20),
                  label: Text(
                    '좋아요 $likes',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _updateLikeDislike(false),
                  icon: const Icon(Icons.thumb_down, size: 20),
                  label: Text(
                    '싫어요 $dislikes',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
