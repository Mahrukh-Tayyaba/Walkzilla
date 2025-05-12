import 'package:flutter/material.dart';
import 'chat_detail_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> chats = [
      {
        'name': 'Alex Johnson',
        'avatar': 'https://randomuser.me/api/portraits/men/1.jpg',
        'lastMessage': 'Are you up for a walk today?',
        'time': '10:32 AM',
        'unread': 2,
        'online': true,
      },
      {
        'name': 'Sarah Miller',
        'avatar': 'https://randomuser.me/api/portraits/children/1.jpg',
        'lastMessage': 'I reached my daily goal!',
        'time': 'Yesterday',
        'unread': 0,
        'online': true,
      },
      {
        'name': 'Walking Group',
        'avatar': 'https://randomuser.me/api/portraits/men/2.jpg',
        'lastMessage': "Maria: Let's meet at the park",
        'time': 'Yesterday',
        'unread': 5,
        'online': false,
      },
      {
        'name': 'Coach David',
        'avatar': 'https://randomuser.me/api/portraits/boys/1.jpg',
        'lastMessage': "Don't forget your exercises today!",
        'time': 'Monday',
        'unread': 0,
        'online': false,
      },
      {
        'name': 'Fitness Challenge',
        'avatar': 'https://randomuser.me/api/portraits/women/1.jpg',
        'lastMessage': 'New challenge starts tomorrow',
        'time': 'Monday',
        'unread': 0,
        'online': true,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          size: 24, color: Colors.black54),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const Text(
                      'Chats',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon:
                      const Icon(Icons.search, size: 28, color: Colors.black54),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView.separated(
        itemCount: chats.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F2)),
        itemBuilder: (context, index) {
          final chat = chats[index];
          return Container(
            color: Colors.white,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Stack(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(chat['avatar']),
                    radius: 28,
                  ),
                  if (chat['online'])
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      chat['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    chat['time'],
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat['lastMessage'],
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (chat['unread'] > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFF03A9F4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          chat['unread'].toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailPage(
                      name: chat['name'],
                      avatar: chat['avatar'],
                      online: chat['online'],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
