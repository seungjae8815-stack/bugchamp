import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/notice_service.dart';
import '../../domain/save_controller.dart';
import '../../l10n/app_localizations.dart';

const _honey = Color(0xFFEBA52F);

/// 공지사항 — 운영이 서버에서 보낸 글 목록. 열면 **읽음 처리**된다.
///
/// 읽음은 id 집합이 아니라 `lastReadNoticeId`(최댓값) 하나로 기록한다.
/// 공지 id 는 증가하는 일련번호라 그걸로 충분하고, 집합은 세이브에 계속 쌓인다.
class NoticeScreen extends ConsumerStatefulWidget {
  const NoticeScreen({super.key});

  @override
  ConsumerState<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends ConsumerState<NoticeScreen> {
  /// 펼쳐 놓은 공지 id.
  final _open = <int>{};
  bool _marked = false;

  /// 목록이 도착하면 1회 읽음 처리. 화면을 나갔다 와도 다시 쓰지 않는다.
  void _markRead(List<Notice> notices) {
    if (_marked || notices.isEmpty) return;
    _marked = true;
    var maxId = 0;
    for (final n in notices) {
      if (n.id > maxId) maxId = n.id;
    }
    final save = ref.read(saveControllerProvider).value;
    if (save == null || save.lastReadNoticeId >= maxId) return;
    // 빌드 도중 상태를 바꾸지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(saveControllerProvider.notifier).markNoticesRead(maxId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(noticesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.noticeTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _empty(l.noticeFailed),
        data: (notices) {
          _markRead(notices);
          if (notices.isEmpty) return _empty(l.noticeEmpty);
          final save = ref.watch(saveControllerProvider).value;
          return ListView.builder(
            padding: EdgeInsets.only(
              top: 8,
              // 마지막 줄이 기기 하단 바에 가리지 않게.
              bottom: 12 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            itemCount: notices.length,
            itemBuilder: (context, i) {
              final n = notices[i];
              // 읽음 처리는 화면 진입 시 이뤄지므로, 배지는 **들어올 때의**
              // 상태로 고정한다(눈앞에서 사라지면 뭐가 새 글이었는지 모른다).
              final isNew = save != null && n.id > _readAtEntry;
              return _card(n, isNew);
            },
          );
        },
      ),
    );
  }

  /// 화면에 들어온 순간의 읽음 기준선(배지 표시용).
  late final int _readAtEntry =
      ref.read(saveControllerProvider).value?.lastReadNoticeId ?? 0;

  Widget _empty(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xB3FFFFFF)),
      ),
    ),
  );

  Widget _card(Notice n, bool isNew) {
    final open = _open.contains(n.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            if (!_open.remove(n.id)) _open.add(n.id);
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (n.pinned)
                      const Padding(
                        padding: EdgeInsets.only(right: 5),
                        child: Icon(Icons.push_pin, size: 13, color: _honey),
                      ),
                    Expanded(
                      child: Text(
                        n.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (isNew)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5252),
                          shape: BoxShape.circle,
                        ),
                      ),
                    Icon(
                      open ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: const Color(0x99FFFFFF),
                    ),
                  ],
                ),
                if (n.createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _date(n.createdAt!),
                      style: const TextStyle(
                        color: Color(0x77FFFFFF),
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                if (open && n.body.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(
                      n.body,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 표시용 날짜(기기 지역시각 기준 yyyy.MM.dd).
  static String _date(DateTime utc) {
    final d = utc.toLocal();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}.$m.$day';
  }
}
